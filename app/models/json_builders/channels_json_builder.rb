# Builds a list of distinct channels that are either verified, excluded or both for the Brave Browser.
#
# Each channel is an array:
# [
#   channel_identifier (string),
#   verified (boolean),
#   excluded (boolean),
#   site_banner details
# ]
#
# ex.
# [
#   ["brave.com", true, false, {title: 'Hello', description: 'world'...}],
#   ["google.com", false, true, {}],
#   ["us.gov", false, false, {}]
# ]

class JsonBuilders::ChannelsJsonBuilder
  include PublishersHelper

  def initialize
    require "publishers/excluded_channels"
    @excluded_channel_ids = Publishers::ExcludedChannels.brave_publisher_id_list
    @excluded_verified_channel_ids = []
    @channels = []
  end

  def build
    joined_verified_channels = join_verified_channels
    joined_verified_channels.each do |verified_channels|
      verified_channels.find_each do |verified_channel|
        include_verified_channel(verified_channel)
      end
    end
    append_excluded
    @channels.to_json
  end
end

def join_verified_channels
  [
    Channel.verified.site_channels.includes(:site_banner).includes(publisher: :site_banners),
    Channel.verified.youtube_channels.includes(:site_banner).includes(publisher: :site_banners),
    Channel.verified.twitch_channels.includes(:site_banner).includes(publisher: :site_banners),
    Channel.verified.twitter_channels.includes(:site_banner).includes(publisher: :site_banners),
    Channel.verified.vimeo_channels.includes(:site_banner).includes(publisher: :site_banners),
    Channel.verified.reddit_channels.includes(:site_banner).includes(publisher: :site_banners),
    Channel.verified.github_channels.includes(:site_banner).includes(publisher: :site_banners),
  ]
end

def include_verified_channel(verified_channel)

  ############################################################################################
  # Step one, if channel is on exclusion list, then skip it.
  ############################################################################################

  return if @excluded_channel_ids.include?(verified_channel.details.channel_identifier)

  ############################################################################################
  # Step two, if channel not on exclusion list, check for KYC'd Uphold.
  ############################################################################################

  return if verified_channel.publisher&.uphold_connection&.is_member != true

  ############################################################################################
  # Step three, if channel not on exclusion list, and publisher has KYC'd, add the channel.
  ############################################################################################

  @channels.push([verified_channel.details.channel_identifier, true, false, site_banner_details(verified_channel)])

end

def append_excluded
  @excluded_channel_ids.each do |excluded_channel_id|
    @channels.push([excluded_channel_id, false, true, {}])
  end
end
