require 'spec_helper'

describe Trakt::Show do

  before do
    @parser = Yajl::Parser.new
  end

  context "seasons_with_episodes" do

    before do
      @seasons_with_episodes = File.read(File.join(File.dirname(__FILE__), '../../', 'fixtures/seasons_with_episodes.json'))
      curl_object = Object.new
      curl_object.stub!(:perform)
      curl_object.stub!(:http_auth_types=)
      curl_object.stub!(:username=)
      curl_object.stub!(:password=)

      curl_object.should_receive(:body_str).and_return(@seasons_with_episodes)
      Curl::Easy.should_receive(:new).and_return(curl_object)

      season = Object.new
      season.stub!(:enriched_results).and_return([])
      Trakt::Show::Season.stub!(:new).and_return(season)
    end

    it "should reverse the seasons for the iPhone app" do
      seasons_with_episodes = Trakt::Show::SeasonsWithEpisodes.new(nil, nil, '12345')

      @parser.parse(seasons_with_episodes.enriched_results).first['season'].should == 0
    end
  end
end