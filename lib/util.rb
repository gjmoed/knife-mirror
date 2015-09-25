# Utility methods, extracted for testing.

module UniverseDiff

  # Universe API returns JSON like the following:
  #   { "cookbook_1": { "v1": {}, "v2", {} ... }, "cookbook_2": ... }
  # Given two universe hashes, calcs the delta that if "added" to the
  # from_universe results in the to_universe.
  def self.calculate_universe_delta(from_universe, to_universe)
    delta = {}

    # New cookbooks
    (to_universe.keys - from_universe.keys).each do |cookbook|
      delta[cookbook] = to_universe[cookbook].dup
    end

    # New versions
    (to_universe.keys & from_universe.keys).each do |cookbook|
      new_versions = to_universe[cookbook].keys - from_universe[cookbook].keys
      new_versions.each do |version|
        delta[cookbook] ||= {}
        delta[cookbook][version] = to_universe[cookbook][version]
      end
    end

    delta
  end

  # Check common cookbooks, versions for dependency changes for the
  # same version.  Note that this would be an error - people should
  # not change dependencies for cookbooks without also changing
  # versions.
  #
  # This is an incomplete check - ideally we'd also check some kind of
  # checksum for changes - but the API doesn't offer anything better
  # to check.
  def self.invalid_dependency_changes(from_universe, to_universe)
    warnings = []
    # Check common cookbooks and versions
    (to_universe.keys & from_universe.keys).each do |cookbook|
      to_cb = to_universe[cookbook]
      from_cb = from_universe[cookbook]
      (to_cb.keys & from_cb.keys).each do |version|
        warnings << "#{cookbook} #{version}" if to_cb[version]["dependencies"] != from_cb[version]["dependencies"]
      end
    end
    warnings
  end
  
  # Returns removed and added cookbooks and versions, and warnings of bad dependencies.
  def self.universe_diff(source, target)
    return [nil, nil] if (source.nil? && target.nil?)
    return [nil, target.dup] if source.nil?
    return [source.dup, nil] if target.nil?
    return [source.dup, target.dup] unless source.is_a?(Hash) && target.is_a?(Hash)

    added = self.calculate_universe_delta(source, target)
    removed = self.calculate_universe_delta(target, source)
    bad_dep_changes = self.invalid_dependency_changes(source, target)
    
    ret = {
      :added => added,
      :removed => removed,
      :invalid_dependency_changes => bad_dep_changes
    }
    ret
  end
  
end
