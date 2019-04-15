require "test_helper"
require "shared/mailer_test_helper"
require "webmock/minitest"

class PublisherTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper
  include MailerTestHelper
  include PromosHelper
  include EyeshadeHelper

  before(:example) do
    @prev_offline = Rails.application.secrets[:api_eyeshade_offline]
  end

  after(:example) do
    Rails.application.secrets[:api_eyeshade_offline] = @prev_offline
  end

  test "verified publishers have both a name and email and have agreed to the TOS" do
    publisher = Publisher.new
    refute publisher.email_verified?
    refute publisher.verified?

    publisher.email = "jane@example.com"
    assert publisher.email_verified?
    refute publisher.verified?

    publisher.name = "Jane"
    refute publisher.verified?

    publisher.agreed_to_tos = 1.minute.ago
    assert publisher.verified?
  end

  test "Publisher is able to have created_by assigned" do
    publisher = Publisher.new(email: 'new@new.com')
    publisher.created_by = Publisher.first
    assert publisher.save
    assert Publisher.find_by(email: 'new@new.com').created_by
  end

  test "Publisher is able to have not have a created_by set" do
    publisher = Publisher.new(email: 'jane@example.com')
    assert publisher.valid?
    assert publisher.save
  end

  test "uphold_code is only valid without uphold_access_parameters and before uphold_verified" do
    publisher = publishers(:verified)
    publisher.uphold_connection.uphold_code = "foo"
    publisher.uphold_connection.uphold_access_parameters = nil
    assert publisher.valid?

    publisher.uphold_connection.uphold_access_parameters = "bar"
    refute publisher.valid?
    assert_equal [:uphold_code], publisher.errors.keys

    publisher.uphold_connection.uphold_access_parameters = nil
    publisher.uphold_connection.uphold_verified = true
    refute publisher.valid?
    assert_equal [:uphold_code], publisher.errors.keys
  end

  test "uphold_access_parameters can not be set when uphold_verified" do
    publisher = publishers(:verified)
    publisher.uphold_connection.uphold_code = nil
    publisher.uphold_connection.uphold_access_parameters = nil
    publisher.uphold_connection.uphold_verified = true
    assert publisher.valid?

    publisher.uphold_connection.uphold_access_parameters = "bar"
    refute publisher.valid?
    assert_equal [:uphold_access_parameters], publisher.errors.keys
  end

  test "prepare_uphold_state_token generates a new uphold_state_token if one does not already exist" do
    publisher = publishers(:verified)
    publisher.uphold_connection.uphold_state_token = nil
    publisher.prepare_uphold_state_token

    assert publisher.uphold_connection.uphold_state_token
    assert publisher.valid?

    uphold_state_token = publisher.uphold_connection.uphold_state_token
    publisher.prepare_uphold_state_token
    assert_equal uphold_state_token, publisher.uphold_connection.uphold_state_token, 'uphold_state_token is not regenerated if it already exists'
  end

  test "receive_uphold_code sets uphold_code and clears other uphold fields" do
    publisher = publishers(:verified)
    publisher.uphold_connection.uphold_state_token = "abc123"
    publisher.uphold_connection.uphold_code = nil
    publisher.uphold_connection.uphold_access_parameters = "bar"
    publisher.uphold_connection.uphold_verified = false
    publisher.receive_uphold_code('secret!')

    assert_equal 'secret!', publisher.uphold_connection.uphold_code
    assert_nil publisher.uphold_connection.uphold_state_token
    assert_nil publisher.uphold_connection.uphold_access_parameters
    assert publisher.valid?
    assert publisher.uphold_connection.uphold_processing?
    assert_equal :code_acquired, publisher.uphold_connection.uphold_status
  end

  test "verify_uphold sets uphold_verified to true and clears uphold_code and uphold_access_parameters" do
    publisher = publishers(:verified)
    publisher.uphold_connection.uphold_code = "foo"
    publisher.uphold_connection.uphold_access_parameters = "bar"
    publisher.uphold_connection.uphold_verified = false
    assert publisher.uphold_connection.uphold_processing?
    publisher.verify_uphold

    assert publisher.uphold_connection.uphold_verified?
    assert publisher.valid?
    refute publisher.uphold_connection.uphold_processing?
  end

  test "disconnect_uphold clears uphold settings" do
    publisher = publishers(:verified)
    publisher.verify_uphold
    assert publisher.uphold_connection.uphold_verified?

    publisher.disconnect_uphold
    refute publisher.uphold_connection.uphold_verified?
    refute publisher.uphold_connection.uphold_processing?
    assert publisher.valid?
  end

  test "verify_uphold_status correctly calculated" do
    publisher = publishers(:verified)

    # unconnected
    publisher.uphold_connection.uphold_code = nil
    publisher.uphold_connection.uphold_access_parameters = nil
    publisher.uphold_connection.uphold_verified = false
    assert publisher.valid?
    assert_equal :unconnected, publisher.uphold_connection.uphold_status

    # code_acquired
    publisher.uphold_connection.uphold_code = "foo"
    publisher.uphold_connection.uphold_access_parameters = nil
    publisher.uphold_connection.uphold_verified = false
    assert publisher.valid?
    assert_equal :code_acquired, publisher.uphold_connection.uphold_status

    # access_parameters_acquired
    publisher.uphold_connection.uphold_code = nil
    publisher.uphold_connection.uphold_access_parameters = "bar"
    publisher.uphold_connection.uphold_verified = false
    assert publisher.valid?
    assert_equal :access_parameters_acquired, publisher.uphold_connection.uphold_status

    # verified
    publisher.uphold_connection.uphold_code = nil
    publisher.uphold_connection.uphold_access_parameters = nil
    publisher.uphold_connection.uphold_verified = true
    assert publisher.valid?
    assert_equal :verified, publisher.uphold_connection.uphold_status
  end

  test "when wallet is gotten the default currency will be sent to eyeshade if it is mismatched" do
    Rails.application.secrets[:api_eyeshade_offline] = false
    publisher = publishers(:verified)
    publisher.default_currency = "USD"

    wallet = {
      defaultCurrency: "CAD"
    }

    stub_all_eyeshade_wallet_responses(publisher: publisher, wallet: wallet)

    assert_enqueued_with(job: UploadDefaultCurrencyJob) do
      publisher.wallet.default_currency
    end
  end

  test "when wallet is gotten the default currency will not be sent to eyeshade if it is equal" do
    publisher = publishers(:verified)
    publisher.default_currency = "USD"

    assert_enqueued_jobs(0) do
      assert_equal "USD", publisher.wallet.default_currency
    end
  end

  test "when wallet is retrieved uphold_status will reflect if reauthorization is needed" do
    prev_offline = Rails.application.secrets[:api_eyeshade_offline]
    begin
      Rails.application.secrets[:api_eyeshade_offline] = false

      publisher = publishers(:uphold_connected)
      assert publisher.uphold_connection.uphold_verified

      wallet = {
        "contributions": {
          "amount": "9001.00",
          "currency": "USD",
          "altcurrency": "BAT",
          "probi": "38077497398351695427000"
        },
        "rates": {
          "BTC": 0.00005418424016883016,
          "ETH": 0.000795331082073117,
          "USD": 0.2363863335301452,
          "EUR": 0.20187818378874756,
          "GBP": 0.1799810085548496
        },
        "status": {
          "provider": "uphold",
          "action": "re-authorize"
        },
        "wallet": {
          "provider": "uphold",
          "authorized": true,
          "defaultCurrency": 'USD',
        }
      }

      stub_all_eyeshade_wallet_responses(publisher: publisher, wallet: wallet)

      publisher.wallet
      assert publisher.uphold_connection.uphold_verified?
      assert publisher.uphold_connection.uphold_reauthorization_needed?
      assert_equal :reauthorization_needed, publisher.uphold_connection.uphold_status

    ensure
      Rails.application.secrets[:api_eyeshade_offline] = prev_offline
    end
  end

  test "uphold_status reflects restricted Uphold registrations" do
    prev_offline = Rails.application.secrets[:api_eyeshade_offline]
    begin
      Rails.application.secrets[:api_eyeshade_offline] = false

      wallet = {
        "contributions": {
          "amount": "9001.00",
          "currency": "USD",
          "altcurrency": "BAT",
          "probi": "38077497398351695427000"
        },
        "rates": {
          "BTC": 0.00005418424016883016,
          "ETH": 0.000795331082073117,
          "USD": 0.2363863335301452,
          "EUR": 0.20187818378874756,
          "GBP": 0.1799810085548496
        },
        "status": {
          "provider": "uphold"
        },
        "wallet": {
          "provider": "uphold",
          "authorized": false,
          "defaultCurrency": 'USD',
        }
      }

      publisher = publishers(:uphold_connected)
      assert publisher.uphold_connection.uphold_verified

      # stub wallet response
      stub_all_eyeshade_wallet_responses(publisher: publisher, wallet: wallet)

      # stub balances response so all PublisherWalletGetter requests are stub'd

      publisher.wallet
      assert publisher.uphold_connection.uphold_verified?
      assert_equal UpholdConnection::UpholdAccountState::RESTRICTED, publisher.uphold_connection.uphold_status
    ensure
      Rails.application.secrets[:api_eyeshade_offline] = prev_offline
    end
  end

  test "a publisher must have a valid pending email address if it does not have an email address" do
    publisher = Publisher.new

    assert_nil publisher.email
    assert_nil publisher.pending_email
    refute publisher.valid?

    publisher.pending_email = "foo@bar.com"
    assert publisher.valid?

    publisher.email = "foo@bar.com"
    publisher.pending_email = nil
    assert publisher.valid?

    publisher.email = "foo@bar.com"
    publisher.pending_email = "bar@bar.com"
    assert publisher.valid?
  end

  test "a publisher pending_email address must be valid" do
    publisher = Publisher.new

    publisher.pending_email = "bad_email_addresscom"
    refute publisher.valid?
  end

  test "a publisher pending_email address must not match an existing verified email address" do
    publisher = Publisher.new

    publisher.pending_email = "foo@bar.com"
    assert publisher.valid?

    publisher.pending_email = "alice@verified.org"
    refute publisher.valid?
  end

  test "a publisher pending_email address must not match the verified email address" do
    publisher = Publisher.new

    publisher.email = "foo@bar.com"
    assert publisher.valid?

    publisher.pending_email = "foo@bar.com"
    refute publisher.valid?
  end

  test "a publisher can be destroyed if it is not verified" do
    publisher = Publisher.new

    publisher.pending_email = "foo@foo.com"
    assert publisher.valid?
    publisher.save
    assert_difference("Publisher.count", -1) do
      assert publisher.destroy
    end
  end

  test "a publisher can not be destroyed if it has channels" do
    publisher = publishers(:verified)
    assert_difference("Publisher.count", 0) do
      refute publisher.destroy
    end
  end

  describe "#history" do
    describe "when the publisher has notes" do
      it 'shows just the notes' do
        histories = publishers(:just_notes).history
        histories.each do |history|
          assert_equal history.class, PublisherNote
        end
      end
    end

    describe "when the publisher has notes and statuses" do
      it 'interweaves the objects' do
        histories = publishers(:notes).history

        assert histories.any? { |h| h.is_a? PublisherNote }
        assert histories.any? { |h| h.is_a? PublisherStatusUpdate }
      end

      it 'sorts the object by created_at time' do
        histories = publishers(:notes).history
        histories.each_with_index do |history, index|
          next if index == 0
          assert history.created_at < histories[index-1].created_at
        end
      end
    end

    describe 'when the publisher just has statuses' do
      it 'just shows the statuses' do
        histories = publishers(:default).history
        histories.each do |history|
          assert_equal history.class, PublisherStatusUpdate
        end
      end
    end
  end

  test "test `has_stale_uphold_code` scopes to correct publishers" do
    publisher = publishers(:default)

    # verify there are no publishers with stale codes to begin with
    assert_equal Publisher.has_stale_uphold_code.count, 0

    # verify scope includes publisher if uphold_code exist and exceeds timeout
    publisher.uphold_connection.uphold_code = "foo"
    publisher.save
    publisher.uphold_connection.uphold_updated_at = UpholdConnection::UPHOLD_CODE_TIMEOUT.ago - 1.minute
    publisher.save
    assert_equal Publisher.has_stale_uphold_code.count, 1

    # verify scope does not include publisher if uphold_code exists and within timeout
    publisher.uphold_connection.uphold_code = "bar"
    publisher.save
    assert_equal Publisher.has_stale_uphold_code.count, 0

    # verify scope does not include publisher if uphold_code does not exist and within timeout
    publisher.uphold_connection.uphold_code = nil
    publisher.save
    assert_equal Publisher.has_stale_uphold_code.count, 0

    # verify scope does not include publisher if uphold_code does not exist and exceeds timeout
    publisher.uphold_connection.uphold_code = nil
    publisher.save!
    publisher.uphold_connection.uphold_updated_at = UpholdConnection::UPHOLD_CODE_TIMEOUT.ago - 1.minute
    publisher.save!
    assert_equal Publisher.has_stale_uphold_code.count, 0
  end

  test "test `has_stale_access_params` scopes to correct publishers " do
    publisher = publishers(:default)

    # verify there are no publishers with stale codes to begin with
    assert_equal Publisher.has_stale_uphold_access_parameters.count, 0

    # verify scope includes publisher if uphold_access_params exist and exceeds timeout
    publisher.uphold_connection.uphold_access_parameters = "foo"
    publisher.save
    publisher.uphold_connection.uphold_updated_at = UpholdConnection::UPHOLD_ACCESS_PARAMS_TIMEOUT.ago - 1.minute
    publisher.save
    assert_equal Publisher.has_stale_uphold_access_parameters.count, 1

    # verify scope does not include publisher if uphold_access_params exists and within timeout
    publisher.uphold_connection.uphold_access_parameters = "bar"
    publisher.save
    assert_equal Publisher.has_stale_uphold_access_parameters.count, 0

    # verify scope does not include publisher if uphold_access_params does not exist and within timeout
    publisher.uphold_connection.uphold_access_parameters = nil
    publisher.save
    assert_equal Publisher.has_stale_uphold_access_parameters.count, 0

    # verify scope does not include publisher if uphold_access_params does not exist and exceeds timeout
    publisher.uphold_connection.uphold_access_parameters = nil
    publisher.save!
    publisher.uphold_connection.uphold_updated_at = UpholdConnection::UPHOLD_CODE_TIMEOUT.ago - 1.minute
    publisher.save!
    assert_equal Publisher.has_stale_uphold_access_parameters.count, 0
  end

  test "test `before_validation :set_uphold_updated_at` updates correctly" do
    publisher = publishers(:default)

    # verify uphold_updated_at has been set after `uphold_state_token` updated
    publisher.uphold_connection.uphold_updated_at = 1.hour.ago
    publisher.save
    publisher.uphold_connection.uphold_state_token = "foo"
    publisher.save
    assert publisher.uphold_connection.uphold_updated_at > 30.minutes.ago

    # verify uphold_updated_at has been set after `uphold_code` updated
    publisher.uphold_connection.uphold_updated_at = 1.hour.ago
    publisher.save
    publisher.uphold_connection.uphold_code = "foo"
    publisher.save
    assert publisher.uphold_connection.uphold_updated_at > 30.minutes.ago

    # verify uphold_updated_at has been set after `uphold_access_parameters` updated
    publisher.uphold_connection.uphold_updated_at = 1.hour.ago
    publisher.uphold_connection.uphold_code = nil
    publisher.save
    publisher.uphold_connection.uphold_access_parameters = "foo"
    publisher.save
    assert publisher.uphold_connection.uphold_updated_at > 30.minutes.ago
  end

  test "formats owner_identifier correctly" do
    publisher = publishers(:default)

    assert_equal "publishers#uuid:02e81b29-f150-54b9-9a08-ce75944f6889", publisher.owner_identifier
  end

  test "a publishers channel details can be selected from the publisher object" do
    publisher = publishers(:completed)
    site_channel_details = publisher.site_channel_details

    assert_equal site_channel_details.first.brave_publisher_id, "completed.org"

    publisher = publishers(:google_verified)
    youtube_channel_details = publisher.youtube_channel_details
    assert_equal youtube_channel_details.first.title, "Some Other Guy's Channel"
  end

  test "created status is added upon create" do
    publisher = Publisher.new(name: "Carol", pending_email: "carol@example.com")
    publisher.save!

    assert publisher.status_updates.count
    assert publisher.last_status_update
  end

  test "onboarding status added to new publishers when they email verify" do
    publisher = publishers(:created) # has no email address

    assert publisher.last_status_update.status == "created"

    publisher.email = "carol@example.com"
    publisher.save!

    assert publisher.last_status_update.status == "onboarding"
  end

  test "onboarding status not added to publishers when they change emails" do
    publisher = publishers(:completed) # has an email address

    publisher.email = "carol@example.com"
    publisher.save!

    refute publisher.last_status_update == "onboarding"
  end

  test "active status is added to publisher after agreeing TOS and addressing 2fa" do
    publisher = publishers(:onboarding)

    assert publisher.last_status_update.status == "onboarding"

    publisher.two_factor_prompted_at = Time.now
    publisher.agreed_to_tos = Time.now
    publisher.save!

    assert publisher.last_status_update.status == "active"
  end

  test "active status is not added to publishers who already agreed to TOS" do
    publisher = publishers(:completed)

    publisher.two_factor_prompted_at = Time.now
    publisher.agreed_to_tos = Time.now
    publisher.save!

    assert publisher.status_updates.count == 1
  end

  test "publisher.last_status_update gets pulls the most recent status update" do
    publisher = publishers(:created)

    # add onboarding status
    publisher.email = "carol@example.com"
    publisher.save!

    # add active status
    publisher.two_factor_prompted_at = Time.now
    publisher.agreed_to_tos = Time.now
    publisher.save!

    assert publisher.status_updates.count == 3
    assert publisher.last_status_update.status == "active"
  end

  test "publisher.can_create_uphold_cards? depends on uphold status and scope" do
    Rails.application.secrets[:api_eyeshade_offline] = false
    publisher = publishers(:created)
    refute publisher.can_create_uphold_cards?

    wallet = {
      "status": {
        "provider": "uphold",
        "action": ""
      },
      "wallet": {
        "provider": "uphold",
        "authorized": true,
        "defaultCurrency": 'USD',
        "scope": ["cards:write"]
      }
    }

    stub_all_eyeshade_wallet_responses(publisher: publisher, wallet: wallet)

    publisher.reload
    publisher.verify_uphold

    publisher.update(excluded_from_payout: true)
    assert_not publisher.can_create_uphold_cards?

    publisher.update(excluded_from_payout: false)
    assert publisher.uphold_connection.uphold_verified?
    assert publisher.can_create_uphold_cards?
  end

  test "suspended scope returns suspended publishers, not_suspended returns not suspended" do
    # ensure all suspended publishers are included in the scope
    suspended_publishers = Publisher.suspended
    not_suspended_publishers = Publisher.not_suspended
    suspended_publishers.each do |publisher|
      assert publisher.last_status_update, PublisherStatusUpdate::SUSPENDED
      assert not_suspended_publishers.exclude?(publisher)
    end

    not_suspended_publishers.each { |publisher| refute publisher.suspended? }

    # ensure a publisher that is unsuspended does not appear in scope
    publisher = publishers(:suspended)
    assert suspended_publishers.include?(publisher)
    status_update = PublisherStatusUpdate.new(status: "active", publisher: publisher)
    status_update.save!
    assert Publisher.suspended.exclude?(publisher)
    assert Publisher.not_suspended.include?(publisher)

    assert_equal Publisher.count, Publisher.suspended.count + Publisher.not_suspended.count
  end

  test "with_verified_channel scope only selects publishers with verified channels" do
    Publisher.with_verified_channel.each do |publisher|
      with_verified_channel = false # initialize to false

      publisher.channels.each do |channel|
        with_verified_channel = true if channel.verified?
      end

      assert with_verified_channel # should have been set to true by at least one channel
    end
  end

  test "with_verified_channel does not select two of the same publisher" do
    publishers = Publisher.with_verified_channel.select(:id)
    assert_equal publishers.uniq.length, publishers.length
  end

  test "#find_by_owner_identifier finds by owner identifier" do
    publisher = Publisher.first
    assert_equal Publisher.find_by_owner_identifier(publisher.owner_identifier), publisher
  end

  test "admin and not_admin scope return collections with only admins and non-admins respectively" do
    admin = publishers(:admin)
    not_admin = publishers(:default)

    assert_includes(Publisher.admin, admin)
    assert_not_includes(Publisher.admin, not_admin)
    assert_includes(Publisher.not_admin, not_admin)
    assert_not_includes(Publisher.not_admin, admin)
  end

  test "partner and not_partner scope return collections with only partners and non-partners respectively" do
    partner = publishers(:partner)
    not_partner = publishers(:default)

    assert_includes(Publisher.partner, partner)
    assert_not_includes(Publisher.partner, not_partner)
    assert_includes(Publisher.not_partner, not_partner)
    assert_not_includes(Publisher.not_partner, partner)
  end

  test "publisher channel_count" do
    result = Publisher.advanced_sort(Publisher::VERIFIED_CHANNEL_COUNT, "asc")
    assert_equal(
      Channel.
      where(verified: true).
      joins(:publisher).
      where(publishers: {role: Publisher::PUBLISHER}).
      pluck(:publisher_id).
      uniq.
      count, result.length
    )
  end

  test "#most_recent_potential_referral_payment finds the most recent referral payment" do
    publisher = publishers(:potentially_paid)
    assert publisher.most_recent_potential_referral_payment.present?

    publisher = publishers(:completed)
    assert publisher.most_recent_potential_referral_payment.blank?
  end
end
