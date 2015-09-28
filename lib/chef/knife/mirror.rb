#
# Author:: G.J. Moed (<gmoed@kobo.com>)
# Copyright:: Copyright (c) 2015 Rakuten Kobo Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
require 'chef/knife'

class Chef
  class Knife
    # Extending Chef Knife with our Mirror additions
    class Mirror < Knife
      banner 'knife mirror COOKBOOK [VERSION] (options)'
      category 'mirror'

      deps do
        require 'chef/cookbook/metadata'
        require 'chef/version_constraint'
        require 'chef/cookbook_site_streaming_uploader'
      end

      option :supermarket_site,
             short: '-m SUPERMARKET_SITE',
             long: '--supermarket-site SUPERMARKET_SITE',
             description: '(Source) Supermarket Site',
             default: 'https://supermarket.chef.io'

      option :target_site,
             short: '-t TARGET_SUPERMARKET_SITE',
             long: '--target-site TARGET_SUPERMARKET_SITE',
             description: '(Destination/target) Supermarket Site'

      option :download_directory,
             short: '-d DOWNLOAD_DIRECTORY',
             long: '--dir DOWNLOAD_DIRECTORY',
             description: 'The directory for storing (--keep) cookbooks failing to process',
             default: Dir.pwd

      option :delay,
             long: '--delay SECONDS',
             description: 'Delay in seconds between per cookbook per version processing, used to throttle downloads and uploads.'

      option :keep,
             long: '--keep',
             description: 'Sometimes really old cookbooks do allow downloading, but fail processing on newer version supermarkets. Do you want to keep these failed cookbooks after downloading?'

      option :deps,
             long: '--deps',
             description: 'Also process cookbook(s) dependencies.'

      option :reps,
             long: '--reps',
             description: 'Also process deprecated cookbook(s) replacement(s). (TODO/WIP)'

      def run
        $stdout.sync = true # Avoid possible buffering of some progress dots
        if @name_args[0] == 'all'
          # Mirror all cookbooks from SUPERMARKET_SITE to TARGET_SUPERMARKET_SITE
          ui.info('Mirroring all versions for all cookbooks')
          ui.info("Delaying by #{config[:delay]} seconds per version.") if config[:delay]
          print "Fetching cookbook index from #{config[:supermarket_site]} (source)... "
          community_universe = unauthenticated_get_rest("#{config[:supermarket_site]}/universe")
          ui.info('Done!')
          print "Fetching cookbook index from #{config[:target_site]} (target)... "
          private_universe = unauthenticated_get_rest("#{config[:target_site]}/universe")
          ui.info('Done!')
          removed, added = universe_diff(private_universe, community_universe)
          ui.info("We are still missing #{added.size} cookbooks (out of #{community_universe.size}) on our target Supermarket.")
          ui.info("Though we're not doing anything with these just yet, you should know we have #{removed.size} cookbooks which are no longer present on the Supermarket (source).") if removed.size > 0
          added.sort.each do |cookbook, versions|
            ui.info("Mirroring #{versions.size} version(s) for #{cookbook} cookbook:")
            displayed_before = false
            versions.sort_by { |version, _versionmeta| version.split('.').map(&:to_i) }.each do |version, _versionmeta|
              mirror_cookbook(cookbook, version, displayed_before)
              displayed_before = true # Some things only need displaying once per cookbook and not each version (deprecation)
              sleep(config[:delay].to_i) if config[:delay]
            end
          end
        elsif @name_args[1] == 'all'
          # Mirror all versions for a specific cookbook
          ui.info("Mirroring all versions for #{@name_args[0]}.")
          ui.info("Delaying by #{config[:delay]} seconds per version.") if config[:delay]
          print "Fetching cookbook meta from #{config[:supermarket_site]} (source)... "
          cookbookmeta = get_cookbook_meta
          ui.info('Done!')
          print "Fetching cookbook meta from #{config[:target_site]} (target)... "
          target_cookbookmeta = get_cookbook_meta(@name_args[0], "#{config[:target_site]}/api/v1/cookbooks")
          ui.info('Done!')
          ui.info("Processing remaining #{cookbookmeta['metrics']['downloads']['versions'].size - target_cookbookmeta['metrics']['downloads']['versions'].size} cookbook versions:")
          displayed_before = false
          (cookbookmeta['metrics']['downloads']['versions'].keys - target_cookbookmeta['metrics']['downloads']['versions'].keys).sort_by { |version| version.split('.').map(&:to_i) }.each do |version|
            mirror_cookbook(@name_args[0], version, displayed_before)
            displayed_before = true # Some things only need displaying once per cookbook and not each version (deprecation)
            sleep(config[:delay].to_i) if config[:delay]
          end
        elsif @name_args.length == 2
          # Mirror just one single cookbook, specific version
          ui.info("Mirroring #{@name_args[0]} (#{@name_args[1]}).")
          mirror_cookbook(@name_args[0], @name_args[1])
        else
          # Mirror just one single cookbook, latest version
          ui.info("Mirroring #{@name_args[0]} (latest version).")
          mirror_cookbook
          if config[:deps]
            ui.info('Mirroring dependencies as well...')
            print "Fetching cookbook index from #{config[:supermarket_site]} (source)... "
            universe = unauthenticated_get_rest("#{config[:supermarket_site]}/universe")
            ui.info('Done!')
            get_cookbook_version_meta['dependencies'].each do |cookbook, version_constraint|
              universe[cookbook].sort_by { |version, _versionmeta| version.split('.').map(&:to_i) }.reverse!.each do |version, _versionmeta|
                next unless Chef::VersionConstraint.new(version_constraint).include?(version)
                ui.info("Most recent version matching constraint (#{version_constraint}) for cookbook #{cookbook}: #{version}")
                mirror_cookbook(cookbook, version)
                sleep(config[:delay].to_i) if config[:delay]
                break
              end
            end
          end
        end
      end

      private

      def mirror_cookbook(cookbook = @name_args[0], version = 'latest_version', displayed_before = false, user_id = Chef::Config[:node_name], user_secret_filename = Chef::Config[:client_key])
        cookbookmeta = get_cookbook_meta(cookbook, "#{config[:supermarket_site]}/api/v1/cookbooks")
        ui.warn("This cookbook has been deprecated. It has been replaced by #{File.basename(cookbookmeta['replacement'])}.") if cookbook_deprecated?(cookbookmeta) && !displayed_before
        versionmeta = version == 'latest_version' ? unauthenticated_get_rest(cookbookmeta['latest_version']) : unauthenticated_get_rest("#{config[:supermarket_site]}/api/v1/cookbooks/#{cookbook}/versions/#{version.gsub('.', '_')}")
        print "Processing version #{versionmeta['version']} "
        temp_cookbookfile = unauthenticated_get_rest(versionmeta['file'], true)
        print '.'
        # Need to revisit this, currently Supermarket only support setting the catagory this way :(
        # meta_hash = %w(category external_url source_url issues_url average_rating created_at up_for_adoption foodcritic_failure).map { |param| [param.to_sym, cookbookmeta[param]] }.to_h
        # meta_hash.merge!('deprecated' => true, 'replacement' => "#{config[:target_site]}/api/v1/cookbooks/#{File.basename(cookbookmeta['replacement'])}") if cookbook_deprecated?(cookbookmeta)
        # So for now, we just fix the category :(
        meta_hash = { 'category' => '' }
        begin
          http_resp = Chef::CookbookSiteStreamingUploader.post("#{config[:target_site]}/api/v1/cookbooks", user_id, user_secret_filename, tarball: File.open(temp_cookbookfile.path), cookbook: meta_hash.to_json)
        rescue => e
          ui.error("Error uploading cookbook #{cookbook} (#{versionmeta['version']}) to the Supermarket at #{config[:target_site]}: #{e.message}. Increase log verbosity (-VV) for more information.")
          Chef::Log.debug("\n#{e.backtrace.join("\n")}")
          config[:keep] ? FileUtils.mv(temp_cookbookfile.path, File.join(config[:download_directory], "#{cookbook}-#{versionmeta['version']}.tar.gz")) : FileUtils.rm_rf(temp_cookbookfile.path)
          exit(1) # Hard exit since this usually hints at trouble reaching the supermarket, no sense in allowing this in some loop...
        end
        print '.'
        if http_resp.code.to_i != 201
          res = Chef::JSONCompat.from_json(http_resp.body) unless http_resp.code.to_i == 500
          ui.info('. Failed :(')
          if http_resp.code.to_i != 500 && res['error_messages']
            ui.error "#{res['error_messages'][0]}"
          else
            ui.error 'Unknown error while uploading cookbook'
            ui.error "Server response: #{http_resp.body}"
          end
          config[:keep] ? FileUtils.mv(temp_cookbookfile.path, File.join(config[:download_directory], "#{cookbook}-#{versionmeta['version']}.tar.gz")) : FileUtils.rm_rf(temp_cookbookfile.path)
          ui.info("Saving failed cookbook (#{File.join(config[:download_directory], "#{cookbook}-#{versionmeta['version']}.tar.gz")})") if config[:keep]
          Chef::Log.debug("Removing #{temp_cookbookfile.path}") unless config[:keep]
          return
        end
        ui.info('. Done!')
      end

      def unauthenticated_get_rest(url, raw = false)
        noauth_rest.sign_on_redirect = false
        noauth_rest.get_rest(url, raw)
      end

      def get_cookbook_meta(cookbook = @name_args[0], api_url = "#{config[:supermarket_site]}/api/v1/cookbooks")
        unauthenticated_get_rest("#{api_url}/#{cookbook}")
      rescue => e
        if e.message =~ /404/
          # Return proper (empty) metadata structure
          md = Chef::Cookbook::Metadata.new
          return md.to_hash.merge!('metrics' => { 'downloads' => { 'versions' => {} } })
        else
          ui.error("Error during #{cookbook} metadata request (#{e.message}). Increase log verbosity (-VV) for more information.")
          exit(1)
        end
      end

      def get_cookbook_version_meta(cookbook = @name_args[0], version = 'latest_version', api_url = "#{config[:supermarket_site]}/api/v1/cookbooks")
        version == 'latest_version' ? unauthenticated_get_rest(get_cookbook_meta(cookbook, api_url)[version]) : unauthenticated_get_rest("#{api_url}/#{cookbook}/versions/#{version.gsub('.', '_')}")
      end

      def cookbook_deprecated?(cookbookmeta)
        cookbookmeta['deprecated'] == true
      end

      def universe_diff(source, target)
        return [nil, target.dup] if source.nil?
        return [source.dup, nil] if target.nil?
        if source.is_a?(Hash) && target.is_a?(Hash)
          added = {}
          removed = {}
          source_keys = source.keys
          target_keys = target.keys
          (source_keys - target_keys).each { |key| removed[key] = source[key].dup }
          (target_keys - source_keys).each { |key| added[key] = target[key].dup }
          (source_keys & target_keys).each do |key|
            nested_removed, nested_added = universe_diff(source[key], target[key])
            removed[key] = nested_removed unless skip?(nested_removed)
            added[key] = nested_added unless skip?(nested_added)
          end
          [removed, added]
        elsif source != target
          [source, target]
        end
      end

      def skip?(obj)
        obj.is_a?(Hash) ? (obj.empty? || %w(location_path download_url).any? { |key| obj.key?(key) }) : obj.nil?
      end
    end
  end
end
