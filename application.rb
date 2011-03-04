require 'sinatra'
require 'lib/api_keys'
require 'lib/initializer'

class Application < Sinatra::Base
  class << self
    attr_accessor :username, :password
  end

  set :root, File.dirname(__FILE__)

  use Rack::Auth::Basic, "iTrakt" do |username, password|
    self.username, self.password = username, password
    username && password
  end

  error { haml :error }

  get '/users/calendar.json' do
    content_type :json
    Trakt::User::Calendar.new(Application.username, Application.password).enriched_results
  end

  get '/users/watched.json' do
    content_type :json
    Trakt::User::Watched.new(Application.username, Application.password).enriched_results
  end

  get '/users/library.json' do
    content_type :json
    Trakt::User::Library.new(Application.username, Application.password).enriched_results
  end


end
