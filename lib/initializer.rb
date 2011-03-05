require 'lib/trakt'
require 'toystore'
require 'adapter/mongo'
require 'carrierwave'

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


class NamespacedShowKeyFactory < Toy::Identity::AbstractKeyFactory
  def key_type
    String
  end

  def next_key(object)
    [object.class.name, object.tvdb_id].join(':')
  end
end

class NamespacedEpisodeKeyFactory < Toy::Identity::AbstractKeyFactory
  def key_type
    String
  end

  def next_key(object)
    [object.class.name, object.show_tvdb_id, object.season_number, object.episode_number].join(':')
  end
end


module CarrierWave
  module Toystore
    include CarrierWave::Mount
    ##
    # See +CarrierWave::Mount#mount_uploader+ for documentation
    #
    def mount_uploader(column, uploader, options={}, &block)
      options[:mount_on] ||= "#{column}_filename"
      attribute options[:mount_on], String

      super

      alias_method :read_uploader, '[]'.to_sym
      alias_method :write_uploader, '[]='.to_sym

      after_save "store_#{column}!".to_sym
      before_save "write_#{column}_identifier".to_sym
      after_destroy "remove_#{column}!".to_sym
    end
  end # Toystore
end # CarrierWave

Toy::Attributes::ClassMethods.send(:include, CarrierWave::Toystore)