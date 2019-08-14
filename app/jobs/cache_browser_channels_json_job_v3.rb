class CacheBrowserChannelsJsonJobV3 < ApplicationJob
  queue_as :heavy

  MAX_RETRY = 10

  def perform
    channels_json = JsonBuilders::ChannelsJsonBuilderV3.new.build
    retry_count = 0
    result = nil

    loop do
      result = Rails.cache.write('browser_channels_json_v3', channels_json)
      break if result || retry_count > MAX_RETRY

      retry_count += 1
      Rails.logger.info("CacheBrowserChannelsJsonJob V3 could not write to Redis result: #{result}. Retrying: #{retry_count}/#{MAX_RETRY}")
    end

    if result
      Rails.logger.info("CacheBrowserChannelsJsonJob V3 updated the cached browser channels json.")
    else
      SlackMessenger.new(message: "🚨 CacheBrowserChannelsJsonJob V3 could not update the channels JSON. @publishers-team  🚨", channel: SlackMessenger::ALERTS)
      Rails.logger.info("CacheBrowserChannelsJsonJob V3 could not update the channels JSON.")
    end
  end
  end