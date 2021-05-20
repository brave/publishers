require "test_helper"
require "webmock/minitest"

class Promo::PeerToPeerRegistrationTest < ActiveJob::TestCase
  before(:example) do
    @prev_promo_api_uri = Rails.application.secrets[:api_promo_base_uri]
  end

  after(:example) do
    Rails.application.secrets[:api_promo_base_uri] = @prev_promo_api_uri
  end

  test "creates a promo for a user" do
    Rails.application.secrets[:api_promo_base_uri] = "http://127.0.0.1:8194/"
    prev_promo_registration_count = PromoRegistration.count
    publisher = publishers(:default)
    stub_request(:put, /api\/2\/promo\/referral_code\/p2p/).to_return(
      status: 200,
      body: [
        {
          "referral_code": "NDF915",
          "ts": "2018-10-12T20:06:50.125Z",
          "type": "peer_to_peer",
          "owner_id": publisher.owner_identifier,
          "channel_id": "",
          "status": "active",
        },
      ].to_json
    )
    PromoClient.peer_to_peer_registration.create(
      publisher: publisher,
      promo_campaign: promo_campaigns(:peer_to_peer_campaign)
    )

    current_promo_registration_count = PromoRegistration.count

    # verify one more promo registration was created
    assert_equal 1, (current_promo_registration_count - prev_promo_registration_count)

    created_promo_registration = PromoRegistration.order("created_at").last

    # verify the new promo registration is created correctly
    assert_equal created_promo_registration.referral_code, "NDF915"
    assert_nil created_promo_registration.channel_id
    assert_equal created_promo_registration.kind, PromoRegistration::PEER_TO_PEER
  end
end
