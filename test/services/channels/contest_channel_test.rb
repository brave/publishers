require "test_helper"
require "webmock/minitest"

class ContestChannelTest < ActiveJob::TestCase
  test "sends two emails" do
    channel = channels(:fraudulently_verified_site)
    contested_by_channel = channels(:locked_out_site)

    assert_enqueued_jobs(3) do
      Channels::ContestChannel.new(channel: channel, contested_by: contested_by_channel).perform
    end
  end

  test "sets verification pending only on contested_by_channel" do
    channel = channels(:fraudulently_verified_site)
    contested_by_channel = channels(:locked_out_site)

    Channels::ContestChannel.new(channel: channel, contested_by: contested_by_channel).perform

    # ensure originally verified channel is not pending, is verified
    refute channel.verification_pending?
    assert channel.verified

    # ensure contesting chanenl is pending, not verified
    assert contested_by_channel.verification_pending?
    refute contested_by_channel.verified

    # ensure channels are linked
    assert_equal channel.contested_by_channel_id, contested_by_channel.id
    assert_equal contested_by_channel.contesting_channel, channel

    # ensure token and timeout is set on verified channel and not on pending
    assert channel.contest_token.present?
    assert channel.contest_timesout_at.present?
    refute contested_by_channel.contest_token.present?
    refute contested_by_channel.contest_timesout_at.present?
  end

  test "raises error if contested channel and contested_by_channel are not the same details_type" do
    channel = channels(:fraudulently_verified_site)
    contested_by_channel = channels(:twitch_new)

    assert_raises(Channels::ContestChannel::ChannelTypeMismatchError) do
      Channels::ContestChannel.new(channel: channel, contested_by: contested_by_channel).perform
    end
  end

  test "raises error if contested channel and contested_by_channel don't have the same details id" do
    channel = channels(:fraudulently_verified_site)
    contested_by_channel = channels(:default)

    assert_raises(Channels::ContestChannel::ChannelIdMismatchError) do
      Channels::ContestChannel.new(channel: channel, contested_by: contested_by_channel).perform
    end
  end

  test "if a channel is contested, then contested again, the second replaces the first" do
    channel = channels(:fraudulently_verified_site)
    contested_by_channel_one = channels(:locked_out_site)
    contested_by_channel_two = Channel.new(publisher: Publisher.new(email: "contest@verified.org"),
                                           details: SiteChannelDetails.new(brave_publisher_id: channel.details.brave_publisher_id))
    contested_by_channel_two.save!

    # contest channel
    Channels::ContestChannel.new(channel: channel, contested_by: contested_by_channel_one).perform
    channel.reload
    contested_by_channel_one.reload

    assert_equal channel.contested_by_channel, contested_by_channel_one
    assert_equal contested_by_channel_one.contesting_channel, channel
    assert contested_by_channel_one.verification_pending

    first_contest_token = channel.contest_token

    # contest channel from a different account
    Channels::ContestChannel.new(channel: channel, contested_by: contested_by_channel_two).perform

    assert_equal channel.contested_by_channel, contested_by_channel_two

    assert_equal contested_by_channel_two.contesting_channel, channel

    assert_not_equal first_contest_token, channel.contest_token
    # ensure original contested_by_channel was deleted when the second contest occurred
    assert Channel.where(id: contested_by_channel_one.id).empty?
  end
end
