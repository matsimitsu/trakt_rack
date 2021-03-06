require 'uri'
require 'yajl'
require 'digest/sha1'
require 'curb'

module Trakt

  def self.base_url
    "http://api.trakt.tv"
  end

  def self.external_url(url)
    return unless url
    "#{root_url}#{url}"
  end

  class Base
    attr_accessor :results, :username, :password, :tvdb_id

    def base_url
      Trakt::base_url
    end

    def request
      request = HTTPI::Request.new
      request.url = url
      request.auth.basic username, password if username && password
      result = HTTPI.get request, :curb
      parser = Yajl::Parser.new
      parser.parse(result.raw_body)
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
          show = ::Show.find_or_fetch_from_tvdb_id(res['tvdb_id'])
          if show
          #  res['poster'] = Trakt::external_url(show.poster_url)
          #  res['thumb'] = Trakt::external_url(show.thumb_url)
            res['overview'] = show['overview']
            res['network'] = show['network']
            res['air_time'] = show['air_time']
          end
          res
        end
        Yajl::Encoder.encode(results)
      end
    end

    class Calendar < Trakt::User::Base

      def url
        "#{base_url}/user/calendar/shows.json/#{Trakt::API_KEY}/#{username}"
      end

      def enriched_results
        return Yajl::Encoder.encode(results)
        results.map do |day|
          day['date_epoch'] = Date.parse(day['date']).strftime('%s')
          day['episodes'].map do |res|
            show = ::Show.find_or_fetch_from_tvdb_id(res['show']['tvdb_id'])
            res['show']['poster'] = Trakt::external_url(show.poster_url)

            res['show']['overview'] = show.overview
            res['show']['network'] = show.network
            res['show']['air_time'] = Time.parse(show.air_time).strftime("%T") rescue nil
            episode = Episode.find_or_fetch_from_show_and_season_and_episode(show, res['episode']['season'], res['episode']['number'])
            res['episode']['overview'] = episode.overview_with_default
            res['episode']['thumb'] = Trakt::external_url(episode.thumb_url)
            res
          end
          day
        end
      end
    end

    class Watched < Trakt::User::Base

      def url
        "#{base_url}/user/watched/episodes.json/#{Trakt::API_KEY}/#{username}"
      end

      def enriched_results
        return Yajl::Encoder.encode(results)
        results.map do |res|
          show = ::Show.find_or_fetch_from_tvdb_id(res['show']['tvdb_id'])
          res['show']['poster'] = Trakt::external_url(show.poster_url)
          res['show']['overview'] = show.overview

          episode = Episode.find_or_fetch_from_show_and_season_and_episode(show, res['episode']['season'], res['episode']['number'])
          res['episode']['overview'] = episode.overview_with_default
          res
        end
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


    class Show < Trakt::Show::Base

      def url
        "#{base_url}/show/summary.json/#{Trakt::API_KEY}/#{tvdb_id}/true"
      end

      def enriched_results
        show = ::Show.find_or_fetch_from_tvdb_id(tvdb_id)
        results['top_episodes'].map do |ep|
          episode = Episode.find_or_fetch_from_show_and_season_and_episode(show, ep['season'], ep['number'])
          ep['overview'] = episode.overview_with_default
          ep['thumb'] = Trakt::external_url(episode.thumb_url)
          ep
        end
        results['poster'] = Trakt::external_url(show.poster_url)
        results['thumb'] = Trakt::external_url(show.thumb_url)
        results
      end
    end

    class SeasonsWithEpisodes < Trakt::Show::Base

      def url
        "#{base_url}/show/seasons.json/#{Trakt::API_KEY}/#{tvdb_id}"
      end

      def enriched_results
        results.each do |season|
          episodes = Trakt::Show::Season.new(username, password, tvdb_id, season['season']).enriched_results
          season['episodes'] = episodes
          season['episode_count'] = episodes.length
        end
      end
    end

    class Seasons < Trakt::Show::Base

      def url
        "#{base_url}/show/seasons.json/#{Trakt::API_KEY}/#{tvdb_id}"
      end

      def enriched_results
        results
      end
    end

    class Season < Trakt::Show::Base
      attr_accessor :season

      def initialize(username, password, tvdb_id, season)
        self.season = season
        super(username, password, tvdb_id)
      end

      def url
        "#{base_url}/show/season.json/#{Trakt::API_KEY}/#{tvdb_id}/#{season}"
      end

      def enriched_results
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
          episode = Episode.find_or_fetch_from_show_and_season_and_episode(show, season, ep['episode'])
          res['show'] = show_result
          res['episode'] = {}
          res['episode']['overview'] = episode.overview_with_default
          res['episode']['thumb'] = Trakt::external_url(episode.thumb_url)
          res['episode']['title'] = episode.name_with_default
          res['episode']['number'] = ep['episode']
          res['episode']['season'] = season
          res['watched'] = ep['watched']
          res['rating'] = ep['ratings']
          return_results << res
        end
        return  return_results
      end
    end

    class Trending < Trakt::Base

      def initialize
        self.results = request
      end

      def url
        "#{Trakt::base_url}/shows/trending.json/#{Trakt::API_KEY}"
      end

      def enriched_results
        results.map do |res|
          show = ::Show.find_or_fetch_from_tvdb_id(res['tvdb_id'])
          res['poster'] = Trakt::external_url(show.poster_url)
          res['thumb'] = Trakt::external_url(show.thumb_url)
          res['network'] = show.network
          res['air_time'] = show.air_time
          res
        end
      end
    end

  end

end