require_relative '../spec_helper'
require_relative '../../lib/chef/knife/mirror'

# Mirror::deps includes "require
# chef/cookbook_site_streaming_uploader".  Adding it explicitly here
# to allow for faking uploading during the tests.
require 'chef/cookbook_site_streaming_uploader'

describe Chef::Knife::Mirror do

  let(:uploader) { class_double("Chef::CookbookSiteStreamingUploader") }
  let(:fake_ui) { double(:ui) }

  def mock_http_responses(url_to_response_map)
    url_to_response_map.each do |url, fixture_file|
      hsh = {
        :body => fixture_content("#{fixture_file}"),
        :status => 200
      }
      json_header = {:headers => { "Content-Type" => "application/json" }}
      hsh.merge!(json_header) if fixture_file.end_with?('.json')
      stub_request(:get, "https://#{url}").to_return { |r| hsh }
    end
  end

  subject(:knife) do
    Chef::Knife::Mirror.new(argv).tap do |k|
      allow(k).to receive(:ui) { fake_ui }
      allow(fake_ui).to receive(:info)

      k.config[:supermarket_site] = "https://COMMUNITY"
      k.config[:target_site] = "https://PRIVATE"
      k.config[:download_directory] = "/some/folder"

      k.set_override_print_destination(StringIO.new)
      k.set_override_uploader(uploader)
    end
  end

  FakeResponse = Struct.new(:code, :body)

  describe '#run', "all" do

    let(:argv) { [ "all" ] }

    context 'when the source supermarket has an extra cookbook' do

      before(:each) do
        request_fixture_map = {
          'PRIVATE/universe' => 'universe_1_cookbook.json',
          'COMMUNITY/universe' => 'universe_2_cookbooks.json',
          'COMMUNITY/api/v1/cookbooks/B' => 'cookbook_B.json',
          'COMMUNITY/api/v1/cookbooks/B/versions/1_0_0' => 'cookbook_B_v_1_0_0.json',
          'COMMUNITY/api/v1/cookbooks/B/versions/1.0.0/download' => 'arbitraryfile.txt'
        }
        mock_http_responses(request_fixture_map)

        expect(uploader).to receive(:post).exactly(1).times

        # contexts define the response code and body.
        allow(uploader).to receive(:post).and_return(FakeResponse.new(*response))
      end

      context 'when the target upload succeeds' do
        let(:response) { ["201", "ok"] }
        it 'mirrors the cookbook' do
          knife.run
          # TODO: this is not really testing the upload ... should
          # extract a testable method and call it from knife.
        end
      end

      context 'when the target upload returns non-201 code' do
        let(:response) { ["999", '{"error_messages": ["some error description"]}'] }
        let(:fileutils) { class_double(FileUtils).as_stubbed_const }

        before(:each) { expect(fake_ui).to receive(:error).with("some error description") }

        it 'prints the error_messages' do
          knife.run
        end

        it 'keeps the file if needed' do
          knife.config[:keep] = true
          expect(fileutils).to receive(:mv)
          knife.run
        end

        it 'deletes the file if not needed' do
          knife.config[:keep] = false
          expect(fileutils).to receive(:rm_rf)
          knife.run
        end
      end

      context 'when the target upload returns 500 error code' do
        let(:response) { ['500', 'some_error'] }
        it 'prints the response' do
          expect(fake_ui).to receive(:error).with(/Unknown error/)
          expect(fake_ui).to receive(:error).with(/some_error/)
          knife.run
        end
      end

      # TODO: tests to add:
      # - if :keep is specified, the :download_directory should exist

    end

    context 'when the source supermarket does not have any new cookbooks' do
      before(:each) do
        request_fixture_map = {
          'COMMUNITY/universe' => 'universe_1_cookbook.json',
          'PRIVATE/universe' => 'universe_2_cookbooks.json'
        }
        mock_http_responses(request_fixture_map)
        expect(uploader).to receive(:post).exactly(0).times
      end

      it 'does not mirror anything' do
        knife.run
      end
    end

    # TODO:
    # - add test for exception thrown on server error.  Need to
    #   get this code into master first, add coverage before making
    #   changes.
    
  end

  # TODO:
  # - tests for specific cookbook mirroring.  Note the code currently
  #   says that a missing cookbook gives a 404, but it appears that
  #   it returns "{"error_messages":["Resource does not exist."],"error_code":"NOT_FOUND"}"
  
end
