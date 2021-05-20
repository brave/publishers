require "test_helper"
require "webmock/minitest"

class Promo::RegistrationGetterTest < ActiveJob::TestCase
  test "raises PublisherChannelMismatchError when requesting referral_code for invalid publisher * channel combo" do
    publisher = publishers(:completed)
    channel = channels(:verified) # publisher does not own channel

    Promo::RegistrationGetter.any_instance.stubs(:active_promo_id).returns("free-bats-2018q1")
    assert_raise Promo::RegistrationGetter::PublisherChannelMismatchError do
      Promo::RegistrationGetter.new(publisher: publisher, channel: channel).perform
    end
  end

  test "returns the promo code for a " do
    publisher = publishers(:completed)
    channel = publisher.channels.first

    # Promo::RegistrationGetter.any_instance.stubs(:active_promo_id).returns("free-bats-2018q1")
    channel_referral_code = Promo::RegistrationGetter.new(publisher: publisher, channel: channel).perform

    assert_not_nil channel_referral_code
  end
end
