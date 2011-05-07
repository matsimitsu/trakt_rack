require 'sinatra'
require 'rack/test'
require 'rspec'

require File.join(File.dirname(__FILE__), '..', 'application.rb')

set :environment, :test

Rspec.configure do |config|

  config.before(:each) do
    [Show, Episode].each { |model| model.store.clear }
  end

end