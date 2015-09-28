require 'webmock/rspec'
require 'test_helpers'

WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  config.include TestHelpers
  config.filter_run :focus => true
  config.run_all_when_everything_filtered = true
end
