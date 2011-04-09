require 'uri'
require 'yajl'
require 'digest/sha1'
require 'typhoeus'

module Trakt

  def self.base_url
    "http://api.trakt.tv"
  end

  def self.external_url(url)
    return unless url
    "#{root_url}#{url}"
  end

  def self.image_exists?(image_url)
    begin
      response = Typhoeus::Request.head(image_url)
      if response.success?
        return true
      else
        return false
      end
    rescue
      return false
    end
  end

  class Base
    attr_accessor :results, :username, :password, :tvdb_id

    def base_url
      Trakt::base_url
    end

    def request
      options = { :disable_ssl_peer_verification => true }
      options.merge!({:username => username, :password => password}) if username && password
      response = Typhoeus::Request.get(url, options.symbolize_keys)
      parser = Yajl::Parser.new
      parser.parse(response.body)
    end
  end

  module User

    class Base < Trakt::Base

      def initialize(username, password)
        self.username = username
        self.password = password
        self.results = request
      end

    end

    class Library < Trakt::User::Base

      def url
        "#{base_url}/user/library/shows.json/#{Trakt::API_KEY}/#{username}"
      end

      def enriched_results
        results.map do |res|
          if (res['tvdb_id'] == "0" || res['tvdb_id'] == 0)
            res
          else
            show = ::Show.find_or_fetch_from_tvdb_id(res['tvdb_id'])
            if show
              res['poster'] = Trakt::external_url(show.poster_url)
              res['thumb'] = Trakt::external_url(show.thumb_url)
              res['overview'] = show['overview']
              res['network'] = show['network']
              res['air_time'] = show['air_time']
              res['season_count'] = show['season_count']
              res['episode_count'] = show['episode_count']
            end
            res
          end
        end
        Yajl::Encoder.encode(results)
      end
    end

    class Calendar < Trakt::User::Base

      def url
        "#{base_url}/user/calendar/shows.json/#{Trakt::API_KEY}/#{username}"
      end

      def enriched_results
        results.map do |day|
          day['date_epoch'] = Date.parse(day['date']).strftime('%s')
          day['episodes'].map do |res|
            show = ::Show.find_or_fetch_from_tvdb_id(res['show']['tvdb_id'])
            res['show']['poster'] = Trakt::external_url(show.poster_url)
            res['show']['overview'] = show.overview
            res['show']['network'] = show.network
            res['show']['air_time'] = show.air_time
            episode = Episode.find_or_fetch_from_show_and_season_and_episode(res['show']['tvdb_id'], res['episode']['season'], res['episode']['number'])
            res['episode']['overview'] = episode.overview_with_default
            res['episode']['thumb'] = Trakt::external_url(episode.thumb_url(show.default_thumb_url))
            res
          end
          day
        end
        Yajl::Encoder.encode(results)
      end
    end
  end

  module Show

    class Base < Trakt::Base

      def initialize(username, password, tvdb_id)
        self.username = username
        self.password = password
        self.tvdb_id = tvdb_id
        self.results = request
      end

    end

    class Recommendations < Trakt::Show::Base

      def initialize(username, password)
        super(username, password, nil)
      end

      def request
        options = {
          :disable_ssl_peer_verification => true,
          :content => { :username => username, :password => password}.to_json,
          :username => username,
          :password => password
        }
        response = Typhoeus::Request.post(url, options.symbolize_keys)
        parser = Yajl::Parser.new
        parser.parse(response.body)
      end

      def url
        "#{base_url}/recommendations/shows.json/#{Trakt::API_KEY}"
      end

      def enriched_results
        results.map do |recommended_show|
          show = ::Show.find_or_fetch_from_tvdb_id(recommended_show['tvdb_id'])
          recommended_show['poster'] = Trakt::external_url(show.poster_url)
          recommended_show['thumb'] = Trakt::external_url(show.thumb_url)
          recommended_show['season_count'] = show['season_count']
          recommended_show['episode_count'] = show['episode_count']
          recommended_show
        end
        Yajl::Encoder.encode(results)
      end

    end

    class Show < Trakt::Show::Base

      def url
        "#{base_url}/show/summary.json/#{Trakt::API_KEY}/#{tvdb_id}/true"
      end

      def enriched_results
        show = ::Show.find_or_fetch_from_tvdb_id(tvdb_id)
        results['poster'] = Trakt::external_url(show.poster_url)
        results['thumb'] = Trakt::external_url(show.thumb_url)
        Yajl::Encoder.encode(results)
      end
    end

    class SeasonsWithEpisodes < Trakt::Show::Base

      def url
        "#{base_url}/show/seasons.json/#{Trakt::API_KEY}/#{tvdb_id}"
      end

      def enriched_results
        results.each do |season|
          episodes = Trakt::Show::Season.new(username, password, tvdb_id, season['season']).enriched_results(false)
          season['episodes'] = episodes
          season['episode_count'] = episodes.length
        end
        Yajl::Encoder.encode(results)
      end
    end

    class Seasons < Trakt::Show::Base

      def url
        "#{base_url}/show/seasons.json/#{Trakt::API_KEY}/#{tvdb_id}"
      end

      def enriched_results
        Yajl::Encoder.encode(results)
      end
    end

    class Season < Trakt::Show::Base
      attr_accessor :season

      def initialize(username, password, tvdb_id, season)
        self.season = season
        self.username = username
        self.password = password
        self.tvdb_id = tvdb_id
        self.results = request
      end

      def url
        "#{base_url}/show/season.json/#{Trakt::API_KEY}/#{tvdb_id}/#{season}"
      end

      def episode(number)
        results.select { |r| r['episode'] == number }.first
      end

      def enriched_results(encoded = true)
        show = ::Show.find_or_fetch_from_tvdb_id(tvdb_id)

        show_result = {}
        show_result['poster'] = Trakt::external_url(show.poster_url)
        show_result['title'] = show.name
        show_result['overview'] = show.overview
        show_result['network'] = show.network
        show_result['air_time'] = Time.parse(show.air_time).strftime("%T") rescue nil

        return_results = []
        results.each do |ep|
          res = {}
          db_episode = Episode.find_or_fetch_from_show_and_season_and_episode(tvdb_id, season, ep['episode'])
          res['show'] = show_result
          res['episode'] = {}
          res['episode']['overview'] = db_episode.overview_with_default
          res['episode']['thumb'] = Trakt::external_url(db_episode.thumb_url(show.default_thumb_url))
          res['episode']['title'] = db_episode.name_with_default
          res['episode']['number'] = ep['episode']
          res['episode']['season'] = season
          res['watched'] = ep['watched'] ? ep['watched'] : false
          res['rating'] = ep['ratings']
          return_results << res
        end
        encoded ? Yajl::Encoder.encode(return_results) : return_results
      end
    end
  end

end