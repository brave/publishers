require "test_helper"
require "webmock/minitest"

class Promo::PublisherChannelsRegistrarTest < ActiveJob::TestCase
  include PromosHelper

  before(:example) do
    @prev_offline = Rails.application.secrets[:api_promo_base_uri]
  end

  after(:example) do
    Rails.application.secrets[:api_promo_base_uri] = @prev_offline
  end

  test "registrar registers a verified channel" do
    publisher = publishers(:completed) # has one verified channel

    assert_difference "PromoRegistration.count", 1 do
      publisher.channels.find_each do |channel|
        Promo::AssignPromoToChannelService.new(channel: channel).perform
      end
    end
  end

  test "registrar does not register unverified channel" do
    publisher = publishers(:default) # has two unverified channels

    assert_no_difference "PromoRegistration.count" do
      publisher.channels.find_each do |channel|
        Promo::AssignPromoToChannelService.new(channel: channel).perform
      end
    end
  end

  test "registrar does not attempt make api call if channel registered" do
    publisher = publishers(:completed)
    channel = publisher.channels.first

    assigning_service = Promo::AssignPromoToChannelService.new(channel: channel)

    assigning_service.perform
    channel.reload

    # verify no registrations created for good measure
    assert_no_difference "PromoRegistration.count" do
      assigning_service.perform
    end
  end

  test "registrar requests promo code for channel if encounters duplicate error" do
    Rails.application.secrets[:api_promo_base_uri] = "http://127.0.0.1:8194"
    publisher = publishers(:completed)

    # Stub Promo response saying the ref code has been taken
    stub_request(:put, "#{Rails.application.secrets[:api_promo_base_uri]}/api/1/promo/publishers").
      to_return(status: 409)

    # Stub Promo response with the referral code and current code owner
    stub_request(:get, "#{Rails.application.secrets[:api_promo_base_uri]}/api/2/promo/referral_code/channel/completed.org").
      to_return(status: 200, body: { referral_code: "COM001", owner_id: "invalid" }.to_json)

    # Stub Promo response when we update the owner
    stub_request(:put, "#{Rails.application.secrets[:api_promo_base_uri]}/api/1/promo/publishers/COM001").
      to_return(status: 200, body: [].to_json)

    assert_difference "PromoRegistration.count", 1 do
      publisher.channels.find_each do |channel|
        Promo::AssignPromoToChannelService.new(channel: channel).perform
      end
    end

    assert_equal PromoRegistration.order("created_at").last.referral_code, "COM001"
  end

  test "reenqueue getting a new referral code if promo server doesn't give back a referral code" do
    Rails.application.secrets[:api_promo_base_uri] = "http://127.0.0.1:8194"
    publisher = publishers(:completed)

    # Stub Promo response with the referral code and current code owner
    stub_request(:put, "#{Rails.application.secrets[:api_promo_base_uri]}/api/1/promo/publishers").
      to_return(status: 500)

    assert_difference "PromoRegistration.count", 0 do
      publisher.channels.find_each do |channel|
        Promo::AssignPromoToChannelService.new(channel: channel).perform
        assert_enqueued_with(job: Promo::RegisterChannelForPromoJob, args: [{ channel_id: channel.id, attempt_count: 1 }])
      end
    end
    assert_performed_jobs 0
    perform_enqueued_jobs(only: Promo::RegisterChannelForPromoJob)
    assert_performed_jobs Promo::AssignPromoToChannelService::MAX_ATTEMPTS
  end
end
