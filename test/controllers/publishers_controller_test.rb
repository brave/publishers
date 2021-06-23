require "test_helper"
require "shared/mailer_test_helper"
require "webmock/minitest"

class PublishersControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActionMailer::TestHelper
  include MailerTestHelper
  include PublishersHelper
  include EyeshadeHelper
  include MockUpholdResponses

  before do
    @prev_eyeshade_offline = Rails.application.secrets[:api_eyeshade_offline]
    stub_uphold_cards!
  end

  after do
    Rails.application.secrets[:api_eyeshade_offline] = @prev_eyeshade_offline
  end

  SIGNUP_PARAMS = {
    email: "alice@example.com",
    terms_of_service: true,
  }.freeze

  COMPLETE_SIGNUP_PARAMS = {
    publisher: {
      name: "Alice the Pyramid",
      visible: true,
    },
  }.freeze

  test "publisher can access a publisher's dashboard" do
    publisher = publishers(:completed)
    sign_in publisher

    get home_publishers_path
    assert_response :success
  end

  test "admin cannot access a publisher's dashboard" do
    admin = publishers(:admin)
    sign_in admin

    get home_publishers_path
    assert_response 302
  end

  test "suspended publisher visits the page for suspended users" do
    publisher = publishers(:completed)
    sign_in publisher

    # Start off as an active user
    publisher.status_updates.create(status: PublisherStatusUpdate::ACTIVE)

    get home_publishers_path
    assert_response 200

    get statements_path
    assert_response 200

    # Get suspended
    publisher.status_updates.create(status: PublisherStatusUpdate::SUSPENDED)

    get home_publishers_path
    assert_redirected_to controller: "/publishers", action: "suspended_error"

    get statements_path
    assert_redirected_to controller: "/publishers", action: "suspended_error"

    # Go back to active
    publisher.status_updates.create(status: PublisherStatusUpdate::ACTIVE)

    get home_publishers_path
    assert_response 200

    get statements_path
    assert_response 200
  end

  test "can create a Publisher registration, pending email verification" do
    assert_difference("Publisher.count") do
      # Confirm email + Admin notification
      assert_enqueued_emails(2) do
        post(registrations_path, params: SIGNUP_PARAMS)
      end
    end
    assert_response 200
    assert_template :emailed_authentication_token

    publisher = Publisher.order(created_at: :asc).last
    get(publisher_path(publisher))
    assert_redirected_to(root_path)
  end

  test "can sign up with an existing email, which will send a login email" do
    assert_no_difference("Publisher.count") do
      # Login email should be generated
      assert_enqueued_emails(1) do
        post(registrations_path, params: { email: "alice@verified.org" })
      end
    end
    assert_response :success
    assert_template :emailed_authentication_token
  end

  test "sends an email with an access link" do
    url = nil
    perform_enqueued_jobs do
      post(registrations_path, params: SIGNUP_PARAMS)
      publisher = Publisher.order(created_at: :asc).last
      email = ActionMailer::Base.deliveries.find do |message|
        message.to.first == SIGNUP_PARAMS[:email]
      end
      assert_not_nil(email)
      url = publisher_url(publisher, token: publisher.reload.authentication_token).gsub("locale=en&", "")
      assert_email_body_matches(matcher: url, email: email)
    end

    get url
    assert_redirected_to controller: "/publishers", action: "email_verified"
  end

  test "re-used access link is rejected and send publisher to the expired auth token page" do
    publisher = publishers(:completed)
    PublisherTokenGenerator.new(publisher: publisher).perform
    url = publisher_url(publisher, token: publisher.authentication_token)

    get url
    assert_redirected_to controller: "/publishers", action: "home"

    get url
    assert_redirected_to expired_authentication_token_publishers_path(id: publisher.id), "re-used URL is rejected, publisher not logged in"
  end

  test "expired login link takes unverified publishers to renew their login link" do
    perform_enqueued_jobs do
      post(registrations_path, params: SIGNUP_PARAMS)
    end
    publisher = Publisher.order(created_at: :asc).last

    # expire token and attempt to cliam
    publisher.user_authentication_token.authentication_token_expires_at = Time.now
    publisher.user_authentication_token.save
    url = publisher_url(publisher, token: publisher.authentication_token)
    get(url)

    # verify that publisher attempt to claim expired token returns expired token page
    assert_redirected_to expired_authentication_token_publishers_path(id: publisher.id)
  end

  test "expired login link takes verified publishers to expired auth token page" do
    publisher = publishers(:verified)

    request_login_email(publisher: publisher)
    url = publisher_url(publisher, token: publisher.reload.authentication_token)

    # expire the token and attempt to claim
    publisher.user_authentication_token.authentication_token_expires_at = Time.now
    publisher.user_authentication_token.save
    get(url)

    # verify that verified publishers are taken to expired token page
    assert_redirected_to expired_authentication_token_publishers_path(id: publisher.id)
    follow_redirect!

    # verify publisher is not redirected to homepage
    assert_response :success
  end

  test "login link of pre-bitflyer enabled japanese users takes them to home" do
    publisher = publishers(:completed)
    headers = { 'Accept-Language' => "ja_JP" }
    request_login_email(publisher: publisher)
    url = publisher_url(publisher, token: publisher.reload.authentication_token)

    get(url, headers: headers)

    # verify that verified publishers are taken to expired token page
    assert_redirected_to home_publishers_path + "?locale=ja"
    follow_redirect!

    # verify publisher is not redirected to homepage
    assert_response :success
  end

  test "login link of new japanese users which should use locale=ja" do
    publisher = publishers(:completed)
    publisher.feature_flags["bitflyer_enabled"] = true
    publisher.save

    headers = { 'Accept-Language' => "ja_JP" }
    request_login_email(publisher: publisher)
    url = publisher_url(publisher, token: publisher.reload.authentication_token)

    get(url, headers: headers)
    # verify that verified publishers are taken to expired token page
    assert_redirected_to home_publishers_path + "?locale=ja"
    follow_redirect!

    # verify publisher is not redirected to homepage
    assert_response :success
  end

  test "an unauthenticated html request redirects to home" do
    get home_publishers_path
    assert_response 302
  end

  test "an unauthenticated json request returns a 401" do
    get home_publishers_path, headers: { 'HTTP_ACCEPT' => "application/json" }
    assert_response 401
  end

  def request_login_email(publisher:)
    perform_enqueued_jobs do
      get(log_in_publishers_path)
      params = publisher.attributes.slice(*%w(brave_publisher_id email))
      put(registrations_path, params: params)
    end
  end

  def request_login_email_uppercase_email(publisher:)
    perform_enqueued_jobs do
      get(log_in_publishers_path)
      params = { email: publisher.email.upcase }
      put(registrations_path, params: params)
    end
  end

  test "relogin sends a login link email" do
    publisher = publishers(:default)
    request_login_email(publisher: publisher)
    email = ActionMailer::Base.deliveries.find do |message|
      message.to.first == publisher.email
    end
    assert_not_nil(email)
    url = publisher_url(publisher, token: publisher.reload.authentication_token).gsub("locale=en&", "")
    assert_email_body_matches(matcher: url, email: email)
  end

  test "relogin email works only once" do
    publisher = publishers(:default)
    request_login_email(publisher: publisher)
    url = publisher_url(publisher, token: publisher.reload.authentication_token)
    get(url)
    follow_redirect!
    sign_out(:publisher)
    get(url)
    assert_empty(css_select("span.email"))
  end

  test "relogin sends a login link email using case insensitive_email comparison" do
    publisher = publishers(:default)
    request_login_email_uppercase_email(publisher: publisher)
    email = ActionMailer::Base.deliveries.find do |message|
      message.to.first == publisher.email
    end

    assert_not_nil(email)
    url = publisher_url(publisher, token: publisher.reload.authentication_token).gsub("locale=en&", "")
    assert_email_body_matches(matcher: url, email: email)
  end

  test "publisher completing signup will agree to TOS" do
    perform_enqueued_jobs do
      post(registrations_path, params: SIGNUP_PARAMS)
    end
    publisher = Publisher.order(created_at: :asc).last
    url = publisher_url(publisher, token: publisher.authentication_token)
    get(url)
    follow_redirect!

    publisher.reload

    perform_enqueued_jobs do
      patch(complete_signup_publishers_path, params: COMPLETE_SIGNUP_PARAMS)
    end

    publisher.reload

    assert publisher.agreed_to_tos.present?
  end

  test "publisher cannot sign up for a long name" do
    perform_enqueued_jobs do
      post(registrations_path, params: SIGNUP_PARAMS)
    end
    publisher = Publisher.order(created_at: :asc).last
    url = publisher_url(publisher, token: publisher.authentication_token)
    get(url)
    follow_redirect!

    publisher.reload

    complete_params = { publisher: { name: "Alice" * 13, visible: true } }

    patch(complete_signup_publishers_path, params: complete_params)
    assert_equal 'Your Name is too long (maximum is 64 characters)', flash[:alert]
  end

  test "publisher updating contact email address will trigger 3 emails and allow publishers confirm new address" do
    perform_enqueued_jobs do
      post(registrations_path, params: SIGNUP_PARAMS)
    end
    publisher = Publisher.order(created_at: :asc).last
    url = publisher_url(publisher, token: publisher.authentication_token)
    get(url)
    follow_redirect!
    perform_enqueued_jobs do
      patch(complete_signup_publishers_path, params: COMPLETE_SIGNUP_PARAMS)
    end

    # verify two emails (one internal) have been sent
    assert ActionMailer::Base.deliveries.count == 2

    # update the publisher email
    perform_enqueued_jobs do
      patch(publishers_path,
            params: { publisher: { pending_email: 'alice-pending@example.com' } },
            headers: { 'HTTP_ACCEPT' => "application/json" })
    end

    publisher.reload

    # verify pending email has been updated
    assert_equal 'alice-pending@example.com', publisher.pending_email

    # verify original email still is used
    assert_equal 'alice@example.com', publisher.email

    # verify 3 emails have been sent after update
    assert ActionMailer::Base.deliveries.count == 5

    # verify notification email sent to original address
    email = ActionMailer::Base.deliveries.find do |message|
      message.to == publisher.email
      message.subject == I18n.t('publisher_mailer.notify_email_change.subject', publication_title: publisher.name)
    end
    assert_not_nil(email)

    # verify brave gets an internal email copy of confirmation email
    email = ActionMailer::Base.deliveries.find do |message|
      message.to.first == Rails.application.secrets[:internal_email]
      message.subject == "<Internal> #{I18n.t('publisher_mailer.confirm_email_change.subject', publication_title: publisher.name)}"
    end
    assert_not_nil(email)

    # verify confirmation email sent to pending address
    email = ActionMailer::Base.deliveries.find do |message|
      message.to == publisher.pending_email
      message.subject == I18n.t('publisher_mailer.confirm_email_change.subject', publication_title: publisher.name)
    end
    assert_not_nil(email)

    url = publisher_url(publisher, confirm_email: publisher.pending_email, token: publisher.authentication_token)
    get(url)
    publisher.reload

    # verify email changes after confirmation
    assert_equal('alice-pending@example.com', publisher.email)

    # verify pending email is removed after confirmation
    assert_nil(publisher.pending_email)
  end

  test "publisher updating contact email address" do
    perform_enqueued_jobs do
      post(registrations_path, params: SIGNUP_PARAMS)
    end

    publisher = Publisher.order(created_at: :asc).last
    url = publisher_url(publisher, token: publisher.authentication_token)
    get(url)
    follow_redirect!
    patch(complete_signup_publishers_path, params: COMPLETE_SIGNUP_PARAMS)

    # update the publisher email
    perform_enqueued_jobs do
      patch(publishers_path,
            params: { publisher: { pending_email: 'alice-pending@example.com' } },
            headers: { 'HTTP_ACCEPT' => "application/json" })
    end

    publisher.reload

    # verify pending email has been updated
    assert_equal 'alice-pending@example.com', publisher.pending_email

    # verify original email still is used
    assert_equal 'alice@example.com', publisher.email

    # verify 3 emails have been sent after update
    assert ActionMailer::Base.deliveries.count == 5

    # verify notification email sent to original address
    email = ActionMailer::Base.deliveries.find do |message|
      message.to == publisher.email
      message.subject == I18n.t('publisher_mailer.notify_email_change.subject', publication_title: publisher.name)
    end
    assert_not_nil(email)

    # verify brave gets an internal email copy of confirmation email
    email = ActionMailer::Base.deliveries.find do |message|
      message.to.first == Rails.application.secrets[:internal_email]
      message.subject == "<Internal> #{I18n.t('publisher_mailer.confirm_email_change.subject', publication_title: publisher.name)}"
    end
    assert_not_nil(email)

    # verify confirmation email sent to pending address
    email = ActionMailer::Base.deliveries.find do |message|
      message.to == publisher.pending_email
      message.subject == I18n.t('publisher_mailer.confirm_email_change.subject', publication_title: publisher.name)
    end
    assert_not_nil(email)

    url = publisher_url(publisher, confirm_email: publisher.pending_email, token: publisher.authentication_token)
    get(url)
    publisher.reload

    # verify email changes after confirmation
    assert_equal('alice-pending@example.com', publisher.email)

    # verify pending email is removed after confirmation
    assert_nil(publisher.pending_email)
  end
  test "after redirection back from uphold and uphold_api is online, a publisher's code is nil and uphold_access_parameters is set" do
    publisher = publishers(:completed)
    sign_in publisher

    uphold_code = 'ebb18043eb2e106fccb9d13d82bec119d8cd016c'
    uphold_state_token = SecureRandom.hex(64)
    publisher.uphold_connection.uphold_state_token = uphold_state_token

    publisher.save!

    stub_request(:post, /oauth2\/token/).
      with(body: "code=#{uphold_code}&grant_type=authorization_code").
      to_return(status: 201, body: "{\"access_token\":\"FAKEACCESSTOKEN\",\"token_type\":\"bearer\",\"refresh_token\":\"FAKEREFRESHTOKEN\",\"scope\":\"cards:write\"}")

    url = publishers_uphold_verified_path
    get(url, params: { code: uphold_code, state: uphold_state_token })
    assert(200, response.status)

    publisher.reload
    # verify that the uphold_state_token has been cleared
    assert_nil(publisher.uphold_connection.uphold_state_token)

    # verify that the uphold_code has been cleared
    assert_nil(publisher.uphold_connection.uphold_code)

    # verify that the uphold_access_parameters has been set
    assert_match('FAKEACCESSTOKEN', publisher.uphold_connection.uphold_access_parameters)

    assert_redirected_to controller: "/publishers", action: "home"
  end

  test "when uphold fails to return uphold_access_parameters, publisher has option to reconnect with uphold" do
    # Turn off promo
    active_promo_id_original = Rails.application.secrets[:active_promo_id]
    Rails.application.secrets[:active_promo_id] = ""
    publisher = publishers(:completed)
    sign_in publisher

    # give pub uphold state token
    uphold_state_token = SecureRandom.hex(64)
    publisher.uphold_connection.uphold_state_token = uphold_state_token
    expected_uphold_code = 'ebb18043eb2e106fccb9d13d82bec119d8cd016c'
    publisher.save

    # simulate return to homepage after creating wallet on uphold.com
    # simulate failed response from uphold.com to get access params
    stub_request(:post, "#{Rails.application.secrets[:uphold_api_uri]}/oauth2/token").
      with(body: "code=#{expected_uphold_code}&grant_type=authorization_code").
      to_timeout
    url = publishers_uphold_verified_path
    get(url, params: { code: expected_uphold_code, state: uphold_state_token })
    follow_redirect!

    # verify uphold :code_acquired but not :access params
    assert_equal publisher.uphold_connection.reload.uphold_status, :code_acquired

    Rails.application.secrets[:active_promo_id] = active_promo_id_original
  end

  test "a publisher's statement can be downloaded as html" do
    publisher = publishers(:uphold_connected)
    sign_in publisher

    get statements_path
    assert_equal response.status, 200
  end

  test "a publisher's wallet can be polled via ajax" do
    publisher = publishers(:uphold_connected)
    sign_in publisher
    stub_request(:get, /me/).to_return(body: { currencies: [] }.to_json)

    get wallet_path, headers: { 'HTTP_ACCEPT' => "application/json" }

    assert_response 200

    wallet_response = JSON.parse(response.body)

    assert wallet_response["wallet"]["channel_balances"].present?
  end

  test "a publisher can destroy his uphold connection" do
    publisher = publishers(:uphold_connected_details)
    sign_in publisher

    delete connection_uphold_connection_path, headers: { 'HTTP_ACCEPT' => "application/json" }

    assert_response 200

    publisher.reload
    refute publisher.uphold_connection
  end

  test "home redirects to 2FA prompt on first visit" do
    publisher = publishers(:unprompted)

    sign_in publisher
    get home_publishers_path
    assert_redirected_to controller: "/publishers/security", action: "prompt"
    follow_redirect!

    get home_publishers_path
    assert_response :success
  end

  test "og meta tags should be set" do
    # ensure meta tags appear on static home apge
    get root_path
    ['og:image', 'og:title', 'og:description', 'og:url', 'og:type'].each do |meta_tag|
      assert_select "meta[property='#{meta_tag}']"
    end

    # ensure meta tags appear in publisher dashboard and elsewhere
    publisher = publishers(:completed)
    sign_in publisher
    get home_publishers_path

    ['og:image', 'og:title', 'og:description', 'og:url', 'og:type'].each do |meta_tag|
      assert_select "meta[property='#{meta_tag}']"
    end
  end

  test "completing signup adds, 'created', 'onboarding', 'active' status updates" do
    # Sign up fresh publisher
    url = nil
    publisher = nil

    perform_enqueued_jobs do
      post(registrations_path, params: SIGNUP_PARAMS)
      publisher = Publisher.find_by(pending_email: SIGNUP_PARAMS[:email])
      assert_equal "created", publisher.last_status_update.status

      ActionMailer::Base.deliveries.find do |message|
        message.to.first == SIGNUP_PARAMS[:email]
      end
      url = publisher_url(publisher, token: publisher.authentication_token)
    end
    get url
    publisher.reload
    # Verify email address
    assert_equal "onboarding", publisher.last_status_update.status

    # Agree to TOS
    perform_enqueued_jobs do
      patch(complete_signup_publishers_path, params: COMPLETE_SIGNUP_PARAMS)
    end

    publisher.reload
    assert publisher.agreed_to_tos.present?

    # Present two factor prompt
    follow_redirect!
    publisher.reload
    assert publisher.two_factor_prompted_at.present?

    assert publisher.last_status_update.status == "active"
  end

  test "publisher login activity is recorded" do
    publisher = publishers(:completed)
    login = publisher.last_login_activity
    assert_nil login

    sign_in publisher
    get home_publishers_path, headers: {
      "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/66.0.3359.181 Safari/537.36",
      "HTTP_ACCEPT_LANGUAGE" => "en-US,en;q=0.9",
    }

    login = publisher.last_login_activity
    assert login
    assert_equal login.user_agent, "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/66.0.3359.181 Safari/537.36"
    assert_equal login.accept_language, "en-US,en;q=0.9"
  end

  test "#confirm_default_currency sets new default currency, initiates CreateUpholdCardsJob if not currency in available currency" do
    Rails.application.secrets[:api_eyeshade_offline] = false
    publisher = publishers(:uphold_connected_currency_unconfirmed)

    sign_in publisher

    confirm_default_currency_params = { default_currency: "BAT" }

    assert_enqueued_with(job: CreateUpholdCardsJob) do
      patch(connection_currency_path, params: confirm_default_currency_params)
    end

    assert_response 200
    assert publisher.uphold_connection.default_currency == "BAT"
  end

  test "#confirm_default_currency creates BTC & BAT card, sets new default currency to BTC" do
    Rails.application.secrets[:api_eyeshade_offline] = false
    publisher = publishers(:uphold_connected_currency_unconfirmed)
    sign_in publisher

    confirm_default_currency_params = { default_currency: "BTC" }

    assert_enqueued_with(job: CreateUpholdCardsJob) do
      patch(connection_currency_path, params: confirm_default_currency_params)
    end

    assert publisher.uphold_connection.default_currency == "BTC"
  end

  describe 'publisher integration with uphold' do
    let(:publisher) { publishers(:completed) }
    before(:example) do
      sign_in publisher

      # skip 2FA prompt
      publisher.two_factor_prompted_at = 1.day.ago
      publisher.save!
    end

    test "after redirection back from uphold and uphold_api is offline, a publisher's code is still set" do
      uphold_state_token = SecureRandom.hex(64)
      publisher.uphold_connection.uphold_state_token = uphold_state_token

      publisher.save!

      uphold_code = 'ebb18043eb2e106fccb9d13d82bec119d8cd016c'

      stub_request(:post, "#{Rails.application.secrets[:uphold_api_uri]}/oauth2/token").
        with(body: "code=#{uphold_code}&grant_type=authorization_code").
        to_timeout

      url = publishers_uphold_verified_path
      get(url, params: { code: uphold_code, state: uphold_state_token })
      assert(200, response.status)
      publisher.reload

      # verify that the uphold_state_token has been cleared
      assert_nil(publisher.uphold_connection.uphold_state_token)

      # verify that the uphold_code has been set
      assert_not_nil(publisher.uphold_connection.uphold_code)
      assert_equal('ebb18043eb2e106fccb9d13d82bec119d8cd016c', publisher.uphold_connection.uphold_code)

      # verify that the uphold_access_parameters has not been set
      assert_nil(publisher.uphold_connection.uphold_access_parameters)

      # verify that the finished_header was not displayed
      refute_match(I18n.t('publishers.finished_header'), response.body)
    end
  end
end
