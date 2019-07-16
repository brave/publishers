module Publishers
  class UpholdController < ApplicationController
    # TODO Refactor Uphold Status to not actually need helper
    # Tradational usage of helpers should really only be for views
    include PublishersHelper

    def uphold_status
      publisher = current_publisher
      respond_to do |format|
        format.json do
          render(json: {
            uphold_status: publisher.uphold_connection&.uphold_status.to_s,
            uphold_status_summary: uphold_status_summary(publisher),
            uphold_status_description: uphold_status_description(publisher),
            uphold_status_class: uphold_status_class(publisher),
          }, status: 200)
        end
      end
    end

    # Records default currency preference
    # If user does not have Uphold's `cards:write` scope, we redirect to Uphold to get authorization
    # Card creation is done in #home
    def confirm_default_currency
      confirm_default_currency_params = publisher_confirm_default_currency_params
      selected_currency = confirm_default_currency_params[:default_currency]

      current_publisher.default_currency_confirmed_at = Time.now
      current_publisher.save!

      default_currency_changed = current_publisher.default_currency != selected_currency

      if default_currency_changed
        current_publisher.default_currency = selected_currency
        current_publisher.save!

        UploadDefaultCurrencyJob.perform_now(publisher_id: current_publisher.id)
      end

      # Check if the publisher is currently missing the ability to create cards
      publisher_missing_write_scope = current_publisher.wallet.scope.exclude? "cards:write"

      if publisher_missing_write_scope
        # Redirect the publisher to Uphold in order to authorize card creation.
        # Card will be created in #home when they return.
        render(json: {
          action: 'redirect',
          status: t("publishers.confirm_default_currency_modal.redirecting"),
          redirectURL: uphold_authorization_endpoint(current_publisher),
          timeout: 3000,
        }, status: 200)
      else
        create_uphold_card_for_default_currency_if_needed

        render(json: {
          action: 'refresh',
          status: t("publishers.confirm_default_currency_modal.refreshing"),
          timeout: 2000,
        }, status: 200)
      end
    end


    # This creates the uphold connection
    # The route for this is by default publisher/uphold_verified
    def create
      @publisher = current_publisher

      # Ensure the uphold_state_token has been set. If not send back to try again
      if @publisher.uphold_connection&.uphold_state_token.blank?
        redirect_to(home_publishers_path, alert: t(".uphold_error"))
        return
      end

      # Catch uphold errors
      uphold_error = params[:error]
      if uphold_error.present?
        redirect_to(home_publishers_path, alert: t(".uphold_error"))
        return
      end

      # Ensure the state token from Uphold matches the uphold_state_token last sent to uphold. If not send back to try again
      state_token = params[:state]
      if @publisher.uphold_connection&.uphold_state_token != state_token
        redirect_to(home_publishers_path, alert: t(".uphold_error"))
        return
      end

      @publisher.uphold_connection.receive_uphold_code(params[:code])

      begin
        ExchangeUpholdCodeForAccessTokenJob.perform_now(publisher_id: @publisher.id)
        @publisher.reload
        @publisher.uphold_connection.reload
      rescue Faraday::Error
        Rails.logger.error("Unable to exchange Uphold access token with uphold")
        redirect_to(home_publishers_path, alert: t(".uphold_error"))
        return
      end

      redirect_to(home_publishers_path)
    end

    def destroy
      publisher = current_publisher
      publisher.uphold_connection.disconnect_uphold
      DisconnectUpholdJob.perform_later(publisher_id: publisher.id)

      head :no_content
    end
  end
end
