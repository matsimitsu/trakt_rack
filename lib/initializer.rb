require 'lib/trakt'
require 'mongo'

module Trakt
  API_KEY = TRAKT_API_KEY
  DB = Mongo::Connection.new.db('itrakt_development')

  def self.root_url
    'http://itrakt.matsimitsu.com'
  end
end

module Tvdb
  API_KEY = TVDB_API_KEY
end