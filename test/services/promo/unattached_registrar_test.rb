require "test_helper"
require "webmock/minitest"

class Promo::UnattachedRegistrarTest < ActiveJob::TestCase
  before(:example) do
    @prev_promo_api_uri = Rails.application.secrets[:api_promo_base_uri]
  end

  after(:example) do
    Rails.application.secrets[:api_promo_base_uri] = @prev_promo_api_uri
  end

  test "creates a unattached promo registration" do
    Rails.application.secrets[:api_promo_base_uri] = "http://127.0.0.1:8194"
    prev_promo_registration_count = PromoRegistration.count

    stub_request(:put, "#{Rails.application.secrets[:api_promo_base_uri]}/api/2/promo/referral_code/unattached?number=1").
      to_return(status: 200, body: [{ "referral_code": "NDF915", "ts": "2018-10-12T20:06:50.125Z", "type": "unattached", "owner_id": "", "channel_id": "", "status": "active" }].to_json)
    Promo::UnattachedRegistrar.new(number: 1).perform

    current_promo_registration_count = PromoRegistration.count

    # verify one more promo registration was created
    assert_equal 1, (current_promo_registration_count - prev_promo_registration_count)

    created_promo_registration = PromoRegistration.order("created_at").last

    # verify the new promo registration is created correctly
    assert_equal created_promo_registration.referral_code, "NDF915"
    assert_nil created_promo_registration.channel_id
    assert_equal created_promo_registration.kind, "unattached"
  end

  test "returns nil if number is <= 0" do
    result = Promo::UnattachedRegistrar.new(number: 0).perform
    assert_nil result
  end
end
