require 'test_helper'
require "webmock/minitest"


class Admin::UnattachedPromoRegistrationsControllerTest < ActionDispatch::IntegrationTest
  include PromosHelper 
  include Devise::Test::IntegrationHelpers

  before(:example) do
    @prev_offline = Rails.application.secrets[:api_promo_base_uri] # Presence of this envar means we use external requiests
  end

  after(:example) do
    Rails.application.secrets[:api_promo_base_uri] = @prev_offline
  end

  test "#create creates codes" do
    Rails.application.secrets[:api_promo_base_uri] = "http://127.0.0.1:8194" # Turn on external requests
    admin = publishers(:admin)
    sign_in admin

    stub_request(:put, "#{Rails.application.secrets[:api_promo_base_uri]}/api/2/promo/referral_code/unattached?number=1")
      .to_return(status: 200, body: [{"referral_code":"NDF915","ts":"2018-10-12T20:06:50.125Z","type":"unattached","owner_id":"","channel_id":"","status":"active"}].to_json)

    assert_difference -> { PromoRegistration.count }, 1 do
      post(admin_unattached_promo_registrations_path, params: {number_of_codes_to_create: "1"})
    end

    assert_equal PromoRegistration.order("created_at").last.kind, "unattached"
  end

  test "#update_statuses updates the status of codes" do
    Rails.application.secrets[:api_promo_base_uri] = "http://127.0.0.1:8194"
    admin = publishers(:admin)
    sign_in admin

    promo_registration = PromoRegistration.create!(referral_code: "ABC123", kind: "unattached", active: true, promo_id: active_promo_id)

    stub_request(:patch, "#{Rails.application.secrets[:api_promo_base_uri]}/api/2/promo/referral?referral_code=ABC123").
      with(body: {status: "paused"}.to_json).
      to_return(status: 200)

    patch(update_statuses_admin_unattached_promo_registrations_path, params: {referral_codes: ["ABC123"], referral_code_status: "paused"})

    refute promo_registration.reload.active
  end

  test "#report downloads a report" do
    Rails.application.secrets[:api_promo_base_uri] = "http://127.0.0.1:8194"
    admin = publishers(:admin)
    sign_in admin

    PromoRegistration.create!(referral_code: "ABC123", kind: "unattached", promo_id: active_promo_id)
    PromoRegistration.create!(referral_code: "DEF456", kind: "unattached", promo_id: active_promo_id)

    stubbed_response_body = [{"referral_code"=>"ABC123",
      "ymd"=>"2018-04-29",
      "retrievals"=>0,
      "first_runs"=>1,
      "finalized"=>1},
     {"referral_code"=>"ABC123",
      "ymd"=>"2018-05-12",
      "retrievals"=>0,
      "first_runs"=>1,
      "finalized"=>0},
     {"referral_code"=>"DEF456",
      "ymd"=>"2018-06-17",
      "retrievals"=>0,
      "first_runs"=>1,
      "finalized"=>0}].to_json

    stub_request(:get, "#{Rails.application.secrets[:api_promo_base_uri]}/api/2/promo/statsByReferralCode?referral_code=ABC123&referral_code=DEF456").
      to_return(status: 200, body: stubbed_response_body)

    get(report_admin_unattached_promo_registrations_path,
        params: { referral_codes: ["ABC123", "DEF456"],
                  event_types: [PromoRegistration::RETRIEVALS, PromoRegistration::FIRST_RUNS, PromoRegistration::FINALIZED],
                  referral_code_report_period: {"start(1i)"=>"2017",
                                                  "start(2i)"=>"10",
                                                  "start(3i)"=>"22",
                                                  "end(1i)"=>"2018",
                                                  "end(2i)"=>"10",
                                                  "end(3i)"=>"22"},
                  reporting_interval: "by_week"

                 })

    assert_equal response.status, 200
    assert_equal response.header["Content-Type"], "application/html"
    assert_match "DEF456", response.body
    assert_match "ABC123", response.body
  end

  test "#assign assigns codes to a campaign" do
    admin = publishers(:admin)
    sign_in admin

    promo_registration_1 = PromoRegistration.create!(referral_code: "ABC123", kind: "unattached", promo_id: active_promo_id)
    promo_registration_2 = PromoRegistration.create!(referral_code: "DEF456", kind: "unattached", promo_id: active_promo_id)
    PromoCampaign.create!(name: "October 2018")

    patch(assign_admin_unattached_promo_registrations_path, params: {referral_codes: ["ABC123", "DEF456"], promo_campaign_target: "October 2018"})

    campaign = PromoCampaign.where(name: "October 2018").first
    
    assert_equal campaign.promo_registrations.count, 2
    assert campaign.promo_registrations.include?(promo_registration_1)
    assert campaign.promo_registrations.include?(promo_registration_2)
  end
end