require 'uploaders/banner_uploader'
require 'uploaders/poster_uploader'
require 'uploaders/default_thumb_uploader'

class Show

  API_FIELDS = {
    :overview => 'overview',
    :genres => 'genres',
    :runtime => 'runtime',
    :name => 'name',
    :first_aired => 'first_aired',
    :network => 'network',
    :tvdb_id => 'id',
    :air_time => 'air_time',
    :runtime => 'runtime',
  }

  def poster_url
    poster_filename.present? ? poster.url(:retina) : nil
  end

  def thumb_url
    default_thumb_filename.present? ? default_thumb.url : '/images/default_thumb.jpg'
  end

  class << self

    def collection
      Trakt::DB.collection('shows')
    end

    def find_or_fetch_from_tvdb_id(tvdb_id)
      result = collection.find('tvdb_id' => tvdb_id)
      if result.count > 0
        result.first
      else
        self.update_or_create_from_tvdb_id(tvdb_id)
      end
    end

    def update_or_create_from_tvdb_id(tvdb_id, default_attributes={})
      tvdb = TvdbParty::Search.new(Tvdb::API_KEY)
      tvdb_show = tvdb.get_series_by_id(tvdb_id)

      new_show_data = {}

      API_FIELDS.each do |fld, remote_fld|
        new_show_data[fld.to_s] = tvdb_show.send(remote_fld)
      end

      new_show_data['first_aired'] = Time.utc(new_show_data['first_aired'].year, new_show_data['first_aired'].month, new_show_data['first_aired'].day)
      new_show_data['air_time'] = Time.parse(new_show_data['air_time']).strftime("%T") if new_show_data['air_time']

      new_show_data[:remote_banner_url] = tvdb_show.series_banners('en').first.url rescue nil
      new_show_data[:remote_poster_url] = tvdb_show.posters('en').first.url rescue nil
      new_show_data[:remote_default_thumb_url] = tvdb_show.fanart('en').first.url rescue nil

      collection.update(
        { 'tvdb_id' => tvdb_id },
        { '$set' => new_show_data },
        { :save => true, :upsert => true}
      )
      new_show_data
    end

  end
end
