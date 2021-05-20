require "test_helper"
require "webmock/minitest"

class Promo::UnattachedRegistrationStatusUpdaterTest < ActiveJob::TestCase
  include PromosHelper

  before(:example) do
    @prev_promo_api_uri = Rails.application.secrets[:api_promo_base_uri]
  end

  after(:example) do
    Rails.application.secrets[:api_promo_base_uri] = @prev_promo_api_uri
  end

  test "has the correct request format" do
    # ensure an external request is attempted to be stubbed by turning on promo
    Rails.application.secrets[:api_promo_base_uri] = "http://127.0.0.1:8194"

    # create two registrations
    PromoRegistration.create(promo_id: active_promo_id, referral_code: "NIC123", kind: "unattached")
    PromoRegistration.create(promo_id: active_promo_id, referral_code: "NIC456", kind: "unattached")

    request_url = "#{Rails.application.secrets[:api_promo_base_uri]}/api/2/promo/referral?referral_code=NIC123&referral_code=NIC456"
    request_body = { status: "paused" }.to_json
    stub_request(:patch, request_url).
      with(body: request_body).
      to_return(status: 200)
    response = Promo::UnattachedRegistrationStatusUpdater.new(promo_registrations: PromoRegistration.where(referral_code: ["NIC123", "NIC456"]),
                                                              status: "paused").perform
    assert_equal response.status, 200
  end
end
