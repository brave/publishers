require 'test_helper'

class PublisherMailerTest < ActionMailer::TestCase
  before do
    @prev_eyeshade_offline = Rails.application.secrets[:api_eyeshade_offline]
  end

  after do
    Rails.application.secrets[:api_eyeshade_offline] = @prev_eyeshade_offline
  end

  test "wallet_not_connected" do
    publisher = publishers(:youtube_new)
    email = PublisherMailer.wallet_not_connected(publisher, 750.0)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal ['brave-publishers@localhost.local'], email.from
    assert_equal [publisher.email], email.to
  end

  test "confirm_email_change" do
    publisher = publishers(:completed)
    publisher.pending_email = "alice-pending@verified.com"
    publisher.save

    # Same logic as ConfirmEmailChangeEmailer
    PublisherTokenGenerator.new(publisher: publisher).perform
    email = PublisherMailer.confirm_email_change(publisher)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal ['brave-publishers@localhost.local'], email.from
    assert_equal [publisher.pending_email], email.to
  end

  test "verify_email error is rescued if there is no send address" do
    publisher = publishers(:completed)
    publisher.pending_email = ""
    publisher.email = "alice_verified@default.org"
    publisher.save

    # verify error raised if no pending email
    assert_nothing_raised do
      # (Albert Wang): VerifyEmailEmailer should be tested but it simply runs the below statements
      PublisherTokenGenerator.new(publisher: publisher).perform
      PublisherMailer.verify_email(publisher: publisher).deliver_now
    end

    publisher.pending_email = "alice_new@default.org"
    publisher.save

    # verify nothing raised if pending email exists
    assert_nothing_raised do
      PublisherMailer.verify_email(publisher: publisher).deliver_now
    end
  end

  test "japanese channel transfer substitutes vars" do
    email = PublisherMailer.channel_transfer_approved_primary("My Channel", "Test", "test@test.com")
    assert_emails 1 do
      email.deliver_now
    end
    refute_match '%{', email.body.encoded
    refute_match '％{', email.body.encoded
  end
end
