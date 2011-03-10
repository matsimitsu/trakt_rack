require 'uploaders/episode_thumb_uploader'

class Episode
  include Toy::Store
  store :mongo, Mongo::Connection.new.db(DB)['episode']
  key NamespacedEpisodeKeyFactory.new

  mount_uploader :thumb, EpisodeThumbUploader


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
    :season_number => 'season_number',
    :episode_number => 'number',
    :writer => 'writer',
    :director => 'director',
    :name => 'name',
    :air_date => 'air_date',
    :guest_stars => 'guest_stars',
    :tvdb_id => 'id',
    :show_tvdb_id => 'series_id'
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
      tvdb = TvdbParty::Search.new(Tvdb::API_KEY)
      tvdb_show = tvdb.get_series_by_id(show_tvdb_id)
      tvdb_episode = tvdb_show.get_episode(season_number, episode_number)

      new_episode_data = {}

      API_FIELDS.each do |fld, remote_fld|
        new_episode_data[fld.to_s] = tvdb_episode.send(remote_fld)
      end

      new_episode_data[:remote_thumb_url] = tvdb_episode.thumb rescue nil

      Episode.create(new_episode_data)
    end

  end

end