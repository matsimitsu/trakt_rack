require 'uploaders/episode_thumb_uploader'

class Episode
  include Toy::Store
  store :mongo, Mongo::Connection.new.db(DB)['episode']
  key NamespacedEpisodeKeyFactory.new

  mount_uploader :thumb, EpisodeThumbUploader

  after_create :clear_cache

  def clear_cache
    CarrierWave.clean_cached_files!
  end

  attribute :tvdb_id, String
  attribute :name, String
  attribute :season_number, Integer
  attribute :episode_number, Integer
  attribute :overview, String
  attribute :writer, String
  attribute :air_date, Date
  attribute :guest_stars, Array
  attribute :show_tvdb_id, String

  index :show_tvdb_id

  API_FIELDS = {
    :overview => 'overview',
    :season_number => 'season',
    :episode_number => 'episode',
    :name => 'title'
  }

  def thumb_url(show_thumb_url)
    thumb_filename.present? ? thumb.url : show_thumb_url
  end

  def overview_with_default
    overview.present? ? overview : "To be announced"
  end

  def name_with_default
    name.present? ? name : "To be announced"
  end

  class << self

    def get(show_tvdb_id, season_number, episode_number)
      super("Episode:#{show_tvdb_id}:#{season_number}:#{episode_number}")
    end

    def find_or_fetch_from_show_and_season_and_episode(show_tvdb_id, season, episode)
      result = Episode.get(show_tvdb_id, season, episode)
      if result
        result
      else
        self.create_from_show_and_season_and_episode(show_tvdb_id, season, episode)
      end
    end

    def create_from_show_and_season_and_episode(show_tvdb_id, season_number, episode_number)
      season = APICache.get("season_#{show_tvdb_id}_#{season_number}", :cache => 3600) do
        Trakt::Show::Season.new(nil, nil, show_tvdb_id, season_number)
      end
      episode = season.episode(episode_number)

      new_episode_data = {}

      API_FIELDS.each do |fld, remote_fld|
        new_episode_data[fld.to_s] = episode[remote_fld]
      end

      new_episode_data[:remote_thumb_url] = episode['images']['screen'] rescue nil
      new_episode_data[:show_tvdb_id] = show_tvdb_id
      new_episode_data[:air_date] = Date.new(episode['first_aired'])
      Episode.create(new_episode_data)
    end

  end

end