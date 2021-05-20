require "test_helper"
require "webmock/minitest"

class YoutubeChannelGetterTest < ActiveJob::TestCase
  test "returns data for a single YouTube channel when channels are requested" do
    token = 'token123'
    channel_data = { 'id' => 'yt123' }

    stub_request(:get, "https://www.googleapis.com/youtube/v3/channels?mine=true&part=statistics,snippet").to_return(status: 200, body: { items: [channel_data] }.to_json, headers: {})

    assert_equal channel_data, YoutubeChannelGetter.new(token: token).perform
  end

  test "returns nil when channels are requested for a YouTube user has no channels" do
    token = 'token123'

    stub_request(:get, "https://www.googleapis.com/youtube/v3/channels?mine=true&part=statistics,snippet").to_return(status: 200, body: {}.to_json, headers: {})

    assert_nil YoutubeChannelGetter.new(token: token).perform
  end

  test "returns data for a single YouTube channel when a particular channel is requested" do
    token = 'token123'
    channel_id = 'yt123'
    channel_data = { 'id' => channel_id }

    stub_request(:get, "https://www.googleapis.com/youtube/v3/channels?id=#{channel_id}&part=statistics,snippet").to_return(status: 200, body: { items: [channel_data] }.to_json, headers: {})

    assert_equal channel_data, YoutubeChannelGetter.new(token: token, channel_id: channel_id).perform
  end

  test "raises a ChannelForbiddenError when a particular channel is requested but can not be accessed" do
    token = 'token123'
    channel_id = 'yt123'

    stub_request(:get, "https://www.googleapis.com/youtube/v3/channels?id=#{channel_id}&part=statistics,snippet").to_return(status: 403, headers: {})

    assert_raises(YoutubeChannelGetter::ChannelForbiddenError) do
      YoutubeChannelGetter.new(token: token, channel_id: channel_id).perform
    end
  end

  test "raises a ChannelNotFoundError when a particular channel is requested but can not be found" do
    token = 'token123'
    channel_id = 'yt123'

    stub_request(:get, "https://www.googleapis.com/youtube/v3/channels?id=#{channel_id}&part=statistics,snippet").to_return(status: 404, headers: {})

    assert_raises(YoutubeChannelGetter::ChannelNotFoundError) do
      YoutubeChannelGetter.new(token: token, channel_id: channel_id).perform
    end
  end

  test "raises a ChannelBadRequestError when a particular channel is requested but an unexpected error is raised" do
    token = 'token123'
    channel_id = 'yt123'

    stub_request(:get, "https://www.googleapis.com/youtube/v3/channels?id=#{channel_id}&part=statistics,snippet").to_return(status: 400, headers: {})

    assert_raises(YoutubeChannelGetter::ChannelBadRequestError) do
      YoutubeChannelGetter.new(token: token, channel_id: channel_id).perform
    end
  end
end
