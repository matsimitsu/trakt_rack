require 'spec_helper'

describe Show do

  context "after create or save" do
    it "should enqueue jobs after save" do
      Navvy::Job.should_receive(:enqueue).with(Episode, :get_images, '123', 1, 1).and_return(true)
      Navvy::Job.should_receive(:enqueue).with(Show, :update_season_episode_count, '123').and_return(true)

      epsisode = Episode.new(:show_tvdb_id => '123', :season_number => 1, :episode_number => 1)
      epsisode.save!
    end

  end

  context ".thumb_url" do

    it "should return thumb url when present" do
      episode = Episode.create!(:thumb_filename => 'thumb.jpg')
      episode.thumb_url('/images/default_thumb.jpg').should == '/public/uploads/thumb.jpg'
    end

    it "should return nil when thumb url is not present" do
      episode = Episode.create!
      episode.thumb_url('/images/default_thumb.jpg').should == '/images/default_thumb.jpg'
    end

  end

  context ".overview_with_default" do

    it "should return value if present" do
      episode = Episode.create!(:overview => 'this is an overview')
      episode.overview_with_default.should == 'this is an overview'
    end

    it "should return default if value is not present" do
      episode = Episode.create!
      episode.overview_with_default.should == 'To be announced'
    end

  end

  context ".name_with_default" do

    it "should return value if present" do
      episode = Episode.create!(:name => 'this is a name')
      episode.name_with_default.should == 'this is a name'
    end

    it "should return default if value is not present" do
      episode = Episode.create!
      episode.name_with_default.should == 'To be announced'
    end

  end

  context "#get" do

    pending "should call get with Show: prefix" do
      Episode.super.should_recieve(:get).with('Episode:123:1:1')
      Episode.get('123', 1, 1)
    end

  end

  context "#find_or_fetch_from_show_and_season_and_episode" do

    it "should return result if found" do
      episode = Episode.create!(:show_tvdb_id => '12345', :season_number => 1, :episode_number => 1)
      Episode.find_or_fetch_from_show_and_season_and_episode('12345', 1, 1).should == episode
    end

    it "should create a new record if not found" do
      Episode.should_receive(:create_from_show_and_season_and_episode).with('54321', 1, 1)
      Episode.find_or_fetch_from_show_and_season_and_episode('54321', 1, 1)
    end
  end

  context "#create_from_show_and_season_and_episode" do

    before do

      @api_fields = {
        :overview => 'overview',
        :season_number => 'season',
        :episode_number => 'episode',
        :name => 'title',
        :image_sources => 'images'
      }

      @episode_data = {
        "screen" => "http://vicmackey.trakt.tv/images/episodes/69-1-1.jpg",
        "title" => "Pilot",
        "overview" => "Liz Lemon is the head writer on a demanding, live TV program in New York City. However, things begin to get complicated when her new boss insists that a wild and unpredictable movie star joins the cast.",
        "ratings" => {
            "votes" => 5,
            "hated" => 0,
            "percentage" => 100,
            "loved" => 5
        },
        "url" => "http://trakt.tv/show/30-rock/season/1/episode/1",
        "first_aired" => 1160550000,
        "episode" => 1,
        "season" => 1,
        "images" => {
            "screen" => "http://vicmackey.trakt.tv/images/episodes/69-1-1.jpg"
        }
      }

      season = Object.new
      season.should_receive(:episode).and_return(@episode_data)
      Trakt::Show::Season.should_receive(:new).with(nil, nil, '12345', 1).and_return(season)
    end

    it "should first check if an episode is in the cache" do
      APICache.should_receive(:get).with("season_12345_1", {:cache=>3600}).and_return(Trakt::Show::Season.new(nil, nil, '12345', 1))
      Episode.create_from_show_and_season_and_episode('12345', 1, 1)
    end

    it "should get trakt data" do
      episode = Episode.create_from_show_and_season_and_episode('12345', 1, 1)

      @api_fields.each do |fld, remote_fld|
        episode.send(fld).should == @episode_data[remote_fld]
      end
    end

  end

  context "#get_images" do

    it "should update the show with image urls" do
      episode = Episode.create(
        :show_tvdb_id => '12345',
        :season_number => 1,
        :episode_number => 1,
        :image_sources => {
          :screen => 'http://test.local/screen.jpg',
        }
      )

      episode.should_receive(:update_attributes).with({
        :remote_thumb_url => 'http://test.local/screen.jpg',
      }).and_return(true)

      Episode.get_images('12345', 1, 1)
    end
  end


end


