require 'lib/api_keys'
require 'lib/initializer'
require 'sinatra'
require 'models/show'
require 'models/episode'


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

  get '/users/library.json' do
    content_type :json
    Trakt::User::Library.new(Application.username, Application.password).enriched_results
  end

  get '/shows/trending.json' do
    content_type :json
    Trakt::Show::Trending.new.enriched_results.to_json
  end

  get '/shows/:id.json' do
    content_type :json
    Trakt::Show::Show.new(Application.username, Application.password, params[:id]).enriched_results.to_json
  end

  get '/shows/:id/seasons_with_episodes.json' do
    content_type :json
    Trakt::Show::SeasonsWithEpisodes.new(Application.username, Application.password, params[:id]).enriched_results.to_json
  end

end