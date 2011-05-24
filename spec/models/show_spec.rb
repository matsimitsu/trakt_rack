require 'spec_helper'

describe Show do

  context "after create or save" do
    it "should clear cache after create" do
      CarrierWave.should_receive(:clean_cached_files!)
      show = Show.new
      show.save!
    end

    it "should enqueue get_images and get_seasons" do
      Navvy::Job.should_receive(:enqueue).twice
      show = Show.new(:tvdb_id => '12345')
      show.save!
    end

    it "should not receive get_images and get_seasons after update" do
      show = Show.create!(:tvdb_id => '12345')
      Navvy::Job.should_not_receive(:enqueue).with(Show, :get_seasons, '12345')
      Navvy::Job.should_not_receive(:enqueue).with(Show, :get_images, '12345')
      show.save!
    end
  end

  context ".poster_url" do

    it "should return poster url when present" do
      show = Show.create!(:poster_filename => 'poster.jpg')
      show.poster_url.should == '/public/uploads/retina_poster.jpg'
    end

    it "should return nil when poster url is not present" do
      show = Show.create!
      show.poster_url.should be_nil
    end

  end

  context ".thumb_url" do

    it "should return thumb url when present" do
      show = Show.create!(:default_thumb_filename => 'thumb.jpg')
      show.thumb_url.should == '/public/uploads/thumb.jpg'
    end

    it "should return nil when thumb url is not present" do
      show = Show.create!
      show.thumb_url.should be_nil
    end

  end

  it "should update the season episode count" do
    show = Show.create(:tvdb_id => '12345')

    show.season_count.should be_nil
    show.episode_count.should be_nil

    Episode.should_receive(:get_season_episode_count).with('12345').and_return({:season_count => 1, :episode_count => 1})
    show.update_season_episode_count

    show.season_count.should == 1
    show.episode_count.should == 1
  end

  pending "should call get with Show: prefix" do
    Show.super.should_recieve(:get).with('Show:12345')
    Show.get('12345')
  end

  context "#find_or_fetch_from_tvdb_id" do

    it "should return result if found" do
      show = Show.create!(:tvdb_id => '12345')
      Show.find_or_fetch_from_tvdb_id('12345').should == show
    end

    it "should create a new record if not found" do
      Show.should_receive(:update_or_create_from_tvdb_id).with('abc123')
      Show.find_or_fetch_from_tvdb_id('abc123')
    end
  end

  context "#update_season_episode_count" do

    it "should find the show and call update_season_episode_count" do
      show = Show.create(:tvdb_id => '12345')
      show.should_receive(:update_season_episode_count)
      Show.should_receive(:get).with('12345').and_return(show)

      Show.update_season_episode_count('12345')
    end

  end


  context "#get_seasons" do

    it "should call the trakt api with tvdb_id" do
      season_with_episodes = Trakt::Show::SeasonsWithEpisodes.new(nil, nil, '12345')
      season_with_episodes.should_receive(:enriched_results)
      Trakt::Show::SeasonsWithEpisodes.should_receive(:new).with(nil, nil, '12345').and_return(season_with_episodes)

      Show.get_seasons('12345')
    end

  end

  context "#get_images" do

    it "should update the show with image urls" do
      show = Show.create(
        :tvdb_id => '12345',
        :image_sources => {
          :poster => 'http://test.local/poster.jpg',
          :fanart => 'http://test.local/fanart.jpg'
        }
      )

      show.should_receive(:update_attributes).with({
        :remote_poster_url => 'http://test.local/poster.jpg',
        :remote_default_thumb_url => 'http://test.local/fanart.jpg'
      }).and_return(true)


      Show.get_images('12345')
    end
  end


  context "#update_or_create_from_tvdb_id" do

    before do
      @api_fields = {
        :overview => 'overview',
        :name => 'title',
        :network => 'network',
        :tvdb_id => 'tvdb_id',
        :runtime => 'runtime',
        :image_sources => 'images'
      }

      @show_data = {
       'overview' => 'Legen... wait for it... dary!',
        'title' => 'How i met your mother',
        'first_aired' => '1234560',
        'network' => 'NBC',
        'tvdb_id' => '12345',
        'air_time' => '12:00:00',
        'runtime' => '30 min',
        'year' => '2005',
        'country' => 'USA',
        'certification' => 'PG13',
        'images' => {
          'poster' => 'http://test.local/poster.jpg',
          'fanart' => 'http://test.local/fanart.jpg'
        }
      }

      show = Object.new
      show.stub!(:results).and_return(@show_data)

      Trakt::Show::Show.should_receive(:new).with(nil, nil, '12345').and_return(show)
    end

    it "should get trakt data" do
      show = Show.update_or_create_from_tvdb_id('12345')

      @api_fields.each do |fld, remote_fld|
        show.send(fld).should == @show_data[remote_fld]
      end
    end

    context "first_aired" do

      it "should parse first_aired" do
        @show_data.merge!('first_aired' => '2001')

        stubbed_show = Object.new
        stubbed_show.stub!(:results).and_return(@show_data)

        show = Show.update_or_create_from_tvdb_id('12345')
        show.first_aired.to_s.should == '2001-01-01'
      end

      it "should not fail on invalid first_aried" do
        @show_data.merge!('first_aired' => nil)

        stubbed_show = Object.new
        stubbed_show.stub!(:results).and_return(@show_data)

        show = Show.update_or_create_from_tvdb_id('12345')
        show.first_aired.to_s.should == ''
      end

    end

    context "air_time" do

      it "should parse air_time" do
        @show_data.merge!('air_time' => '09:00')

        stubbed_show = Object.new
        stubbed_show.stub!(:results).and_return(@show_data)

        show = Show.update_or_create_from_tvdb_id('12345')
        show.air_time.to_s.should == '09:00:00'
      end

      it "should not fail on invalid air_time" do
        @show_data.merge!('air_time' => nil)

        stubbed_show = Object.new
        stubbed_show.stub!(:results).and_return(@show_data)

        show = Show.update_or_create_from_tvdb_id('12345')
        show.air_time.to_s.should == '00:00:00'
      end

    end

  end

end