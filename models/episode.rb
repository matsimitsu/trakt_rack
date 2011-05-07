require 'uploaders/episode_thumb_uploader'
require 'api_cache'

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
  attribute :image_sources, Hash

  index :show_tvdb_id

  API_FIELDS = {
    :overview => 'overview',
    :season_number => 'season',
    :episode_number => 'episode',
    :name => 'title',
    :image_sources => 'images'
  }

  after_save :enqueue_update_show_season_episode_count

  after_create :enqueue_get_images

  def enqueue_get_images
    Navvy::Job.enqueue(Episode, :get_images, show_tvdb_id, season_number, episode_number)
  end

  def enqueue_update_show_season_episode_count
    Navvy::Job.enqueue(Show, :update_season_episode_count, show_tvdb_id)
  end

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

      new_episode_data[:show_tvdb_id] = show_tvdb_id
      new_episode_data[:air_date] = Date.new(episode['first_aired'])
      Episode.create(new_episode_data)
    end

    def get_season_episode_count(tvdb_id)
      seasons = []
      episodes = 0
      self.store.client.find( 'show_tvdb_id' => tvdb_id ).each do |res|
        episodes += 1;
        seasons << res['season_number']
      end
      { :episode_count => episodes, :season_count => seasons.uniq.length }
    end

    def get_images(show_tvdb_id, season, episode)
      episode = Episode.get(show_tvdb_id, season, episode)

      new_episode_data = {}
      new_episode_data[:remote_thumb_url] = episode.image_sources['screen']

      episode.update_attributes(new_episode_data)
    end

  end

end