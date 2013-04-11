require 'rspec'
require 'growl-rspec'

RSpec.configure do |config|
  config.formatter = 'Growl::RSpec::Formatter'
end

