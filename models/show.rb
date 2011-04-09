require 'uploaders/banner_uploader'
require 'uploaders/poster_uploader'
require 'uploaders/default_thumb_uploader'

class Show
  include Toy::Store

  store :mongo, Mongo::Connection.new.db(DB)['show']

  mount_uploader :poster, PosterUploader
  mount_uploader :default_thumb, DefaultThumbUploader

  key NamespacedShowKeyFactory.new

  after_create :clear_cache

  def clear_cache
    CarrierWave.clean_cached_files!
  end

  attribute :name, String
  attribute :genres, Array
  attribute :runtime, String
  attribute :overview, String
  attribute :first_aired, Date
  attribute :network, String
  attribute :tvdb_id, String
  attribute :air_time, String
  attribute :season_count, Integer
  attribute :episode_count, Integer

  index :tvdb_id

  API_FIELDS = {
    :overview => 'overview',
    :name => 'title',
    :first_aired => 'first_aired',
    :network => 'network',
    :tvdb_id => 'tvdb_id',
    :air_time => 'air_time',
    :runtime => 'runtime',
    :year => 'year',
    :country => 'country',
    :certification => 'certification'
  }

  def poster_url
    poster_filename.present? ? poster.url(:retina) : nil
  end

  def thumb_url
    default_thumb_filename.present? ? default_thumb.url : '/images/default_thumb.jpg'
  end

  def update_season_episode_count
    info = Episode.get_season_episode_count(tvdb_id)
    update_attributes(info)
  end

  class << self

    def get(tvdb_id)
      super("Show:#{tvdb_id}")
    end

    def find_or_fetch_from_tvdb_id(tvdb_id)
      result = Show.get(tvdb_id)
      if result
        result
      else
        self.update_or_create_from_tvdb_id(tvdb_id)
      end
    end

    def update_or_create_from_tvdb_id(tvdb_id, default_attributes={})
      trakt_show = Trakt::Show::Show.new(nil, nil, tvdb_id).results

      new_show_data = {}

      API_FIELDS.each do |fld, remote_fld|
        new_show_data[fld.to_s] = trakt_show[remote_fld]
      end

      begin
        new_show_data['first_aired'] = Time.utc(new_show_data['first_aired'])
      rescue
        puts new_show_data.inspect
      end

      if new_show_data['air_time']
        begin
          new_show_data['air_time'] = Time.parse(new_show_data['air_time']).strftime("%T")
        rescue ArgumentError
          new_show_data['air_time'] = "00:00:00"
        end
      else
        new_show_data['air_time'] = "00:00:00"
      end

      if Trakt::image_exists?(trakt_show['images']['poster'])
        new_show_data[:remote_poster_url] = trakt_show['images']['poster']
      end

      if Trakt::image_exists?(trakt_show['images']['fanart'])
        new_show_data[:remote_default_thumb_url] = trakt_show['images']['fanart']
      end

      Show.create(new_show_data)
    end

  end
end
