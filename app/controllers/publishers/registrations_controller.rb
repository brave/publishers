module Publishers
  class RegistrationsController < ApplicationController
    # Number of requests to #create before we present a captcha.
    THROTTLE_THRESHOLD_CREATE = 3
    THROTTLE_THRESHOLD_LOG_IN = 3
    THROTTLE_THRESHOLD_RESEND_AUTH_EMAIL = 3


    before_action :require_unauthenticated_publisher,
      only: %i(sign_up
              create
              create_auth_token
              new
              new_auth_token)

    # Log in page
    def sign_up
      @publisher = Publisher.new(email: params[:email])
    end

    def log_in
      @publisher = Publisher.new
    end

    def log_out
      path = after_sign_out_path_for(current_publisher)
      sign_out
      redirect_to(path)
    end

    # Used by sign_up.html.slim.  If a user attempts to sign up with an existing email, a log in email
    # is sent to the existing user. Otherwise, a new publisher is created and a sign up email is sent.
    def create
      enforce_throttle!(throttled: should_throttle_create?, path: root_path(captcha: params[:captcha]))

      # First check if publisher with the email already exists.
      existing_publisher = Publisher.by_email_case_insensitive(params[:email]).first
      return email_existing_publisher(existing_publisher) if existing_publisher

      # Check if an existing email unverified publisher record exists to prevent duplicating unverified publishers.
      # Requiring `email: nil` ensures we do not select a publisher with the same pending_email
      # as a publisher in the middle of the change email flow
      @publisher = Publisher.find_or_create_by(pending_email: params[:email], email: nil)
      @publisher_email = @publisher.pending_email

      if @publisher.save
        MailerServices::VerifyEmailEmailer.new(publisher: @publisher).perform
        render :emailed_authentication_token
      else
        Rails.logger.error("Create publisher errors: #{@publisher.errors.full_messages}")
        flash[:warning] = t(".invalid_email")
        redirect_to sign_up_publishers_path
      end
    end

    def email_existing_publisher(publisher)
      @publisher = publisher
      @publisher_email = publisher.email
      MailerServices::PublisherLoginLinkEmailer.new(publisher: @publisher).perform
      flash.now[:notice] = t("publishers.registrations.create.email_already_active", email: @publisher_email)
      render :emailed_authentication_token
    end

    # This is the method that is called after the user clicks the "Log In" button
    # If the user is an existing publisher we will send them a log in link, if they are not
    # then we provide the ability to create an account by clicking the alert on the page.
    def update
      @publisher = Publisher.by_email_case_insensitive(params[:email]).first

      enforce_throttle!(throttled: should_throttle_log_in?, path: log_in_publishers_path )

      if @publisher
        MailerServices::PublisherLoginLinkEmailer.new(publisher: @publisher).perform
      else
        # Failed to find publisher
        flash[:alert_html_safe] = t('publishers.registrations.emailed_authentication_token.unfound_alert_html', {
          new_publisher_path: sign_up_publishers_path(email: params[:email]),
          create_publisher_path: registrations_path(email: params[:email]),
          email: ERB::Util.html_escape(params[:email])
        })

        @publisher = Publisher.new
        return redirect_to log_in_publishers_path
      end

      render :emailed_authentication_token
    end

    def expired_authentication_token
      @publisher = Publisher.find(params[:publisher_id])
      if @publisher.verified?
        return
      end

      redirect_to(root_path, alert: t(".expired_error"))
    end

    # Used by emailed_authentication_token.html.slim to send a new sign up or log in access email
    # to the publisher passed through the params
    def resend_authentication_email
      enforce_throttle!(throttled: should_throttle_resend_auth_email?, path: log_in_publishers_path)
      @publisher = Publisher.find(params[:publisher_id])

      @should_throttle = should_throttle_resend_auth_email?
      throttle_legit = @should_throttle ? verify_recaptcha(model: @publisher) : true

      if @publisher.email.nil?
        MailerServices::VerifyEmailEmailer.new(publisher: @publisher).perform
        @publisher_email = @publisher.pending_email
      else
        @publisher_email = @publisher.email
        MailerServices::PublisherLoginLinkEmailer.new(publisher: @publisher).perform
      end

      flash.now[:notice] = t(".done")
      render(:emailed_authentication_token)
    end

    private

    def enforce_throttle!(throttled:, path:)
      @should_throttle = throttled
      throttle_legit = @should_throttle ? verify_recaptcha(model: @publisher) : true
      if !throttle_legit
        return redirect_to path, alert: t(".access_throttled")
      end
    end

    # Level 1 throttling -- After the first two requests, ask user to
    # submit a captcha. See rack-attack.rb for throttle keys.
    def manually_triggered_captcha?
      params[:captcha].present?
    end

    def should_throttle_create?
      manually_triggered_captcha? ||
      request.env["rack.attack.throttle_data"] &&
      request.env["rack.attack.throttle_data"]["registrations/ip"] &&
      request.env["rack.attack.throttle_data"]["registrations/ip"][:count] >= THROTTLE_THRESHOLD_CREATE
    end

    def should_throttle_log_in?
      manually_triggered_captcha? ||
      request.env["rack.attack.throttle_data"] &&
      request.env["rack.attack.throttle_data"]["created-auth-tokens/ip"] &&
      request.env["rack.attack.throttle_data"]["created-auth-tokens/ip"][:count] >= THROTTLE_THRESHOLD_LOG_IN
    end

    def should_throttle_resend_auth_email?
      manually_triggered_captcha? ||
      request.env["rack.attack.throttle_data"] &&
      request.env["rack.attack.throttle_data"]["resend_auth_email/publisher_id"] &&
      request.env["rack.attack.throttle_data"]["resend_auth_email/publisher_id"][:count] >= THROTTLE_THRESHOLD_RESEND_AUTH_EMAIL
    end

    # If an active session is present require users to explicitly sign out
    def require_unauthenticated_publisher
      return if !current_publisher
      redirect_to(publisher_next_step_path(current_publisher))
    end

    def require_verified_email
      return if current_publisher.email_verified?
      redirect_to(publisher_next_step_path(current_publisher), alert: t(".email_verification_required"))
    end

  end
end
