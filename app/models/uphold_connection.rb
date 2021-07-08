# frozen_string_literal: true

class UpholdConnection < ApplicationRecord
  include WalletProviderProperties

  has_paper_trail only: [:is_member, :member_at, :uphold_id, :address, :status, :default_currency]

  UPHOLD_CODE_TIMEOUT = 5.minutes
  UPHOLD_ACCESS_PARAMS_TIMEOUT = 2.hours

  # Snooze for the next ~ 80 years, this is what I consider forever from now :)
  FOREVER_DATE = DateTime.new(2100, 1, 1)

  USE_BROWSER = 1

  attr_encrypted :uphold_code, key: proc { |record| record.class.encryption_key }
  attr_encrypted :uphold_access_parameters, key: proc { |record| record.class.encryption_key }

  class UpholdAccountState
    REAUTHORIZATION_NEEDED      = :reauthorization_needed
    VERIFIED                    = :verified
    ACCESS_PARAMETERS_ACQUIRED  = :access_parameters_acquired
    CODE_ACQUIRED               = :code_acquired
    UNCONNECTED                 = :unconnected
    # (Albert Wang): Consider adding refactoring all of the above states as they
    # aren't valid states: https://uphold.com/en/developer/api/documentation/#user-object
    RESTRICTED      = :restricted
    BLOCKED         = :blocked
  end

  OK = "ok"
  PENDING = "pending"
  BLOCKED = "blocked"
  RESTRICTED = "restricted"

  JAPAN = "JP"

  belongs_to :publisher

  has_many :uphold_connection_for_channels

  # uphold_code is an intermediate step to acquiring uphold_access_parameters
  # and should be cleared once it has been used to get uphold_access_parameters
  validates :uphold_code, absence: true, if: -> { uphold_access_parameters.present? || uphold_verified? }

  # publishers that have uphold codes that have been sitting for five minutes
  # can be cleared if publishers do not create wallet within 5 minute window
  scope :has_stale_uphold_code, -> {
    where.not(encrypted_uphold_code: nil).
      where("updated_at < ?", UPHOLD_CODE_TIMEOUT.ago)
  }

  # If the user became KYC'd let's create the uphold card for them
  after_save :create_uphold_cards, if: -> { saved_change_to_is_member? || saved_change_to_default_currency? }
  after_save :update_site_banner_lookup!, if: -> { saved_change_to_is_member? }
  after_save :update_promo_status, if: -> { saved_change_to_is_member? }

  # publishers that have access params that havent accepted by eyeshade
  # can be cleared after 2 hours
  scope :has_stale_uphold_access_parameters, -> {
    where.not(encrypted_uphold_access_parameters: nil).
      where("updated_at < ?", UPHOLD_ACCESS_PARAMS_TIMEOUT.ago)
  }

  # This state token is generated and must be unique when connecting to uphold.
  def prepare_uphold_state_token!
    self.uphold_state_token = SecureRandom.hex(64).to_s
    save!
  end

  def scope
    @scope ||= JSON.parse(uphold_access_parameters || '{}').try(:[], 'scope') || []
  end

  def can_read_transactions?
    scope.include?('transactions:read')
  end

  def receive_uphold_code(code)
    update(
      uphold_code: code,
      uphold_state_token: nil,
      uphold_access_parameters: nil,
      uphold_verified: false,
    )
  end

  # Public: Determines if a user needs to reconnect their Uphold account.
  #         If the user doesn't have a valid acess scope, or Uphold returns a 401
  #         then we tell the user to re-authorize.
  #
  # Returns true or false
  def uphold_reauthorization_needed?
    # TODO Let's make sure that if we can't access the user's information then we set uphold_verified? to false
    # Perhaps through a rescue on 401
    uphold_verified? &&
      (uphold_access_parameters.blank? || scope.exclude?('cards:write') || uphold_details.nil?)
  end

  # Makes a remote HTTP call to Uphold to get more details
  # TODO should we actually call uphold_user?

  def uphold_details
    @user ||= UpholdClient.user.find(self)
  rescue Faraday::ClientError => e
    if e.response&.dig(:status) == 401
      Rails.logger.info("#{e.response[:body]} for uphold connection #{id}")
      update(uphold_access_parameters: nil)
      nil
    else
      raise
    end
  end

  def uphold_status
    send_blocked_message if status == UpholdAccountState::BLOCKED

    if status == UpholdAccountState::RESTRICTED
      UpholdAccountState::RESTRICTED
    elsif uphold_reauthorization_needed?
      UpholdAccountState::REAUTHORIZATION_NEEDED
    elsif uphold_verified? && !is_member?
      UpholdAccountState::RESTRICTED
    elsif uphold_verified? && is_member?
      UpholdAccountState::VERIFIED
    elsif uphold_code.present?
      :code_acquired
    else
      UpholdAccountState::UNCONNECTED
    end
  end

  def username
    uphold_details&.username
  end

  def unconnected?
    uphold_status == UpholdAccountState::UNCONNECTED
  end

  def payable?
    uphold_status == UpholdAccountState::VERIFIED && status == OK
  end

  def verify_url
    Rails.application.secrets[:uphold_dashboard_url]
  end

  def can_create_uphold_cards?
    uphold_verified? &&
      uphold_access_parameters.present? &&
      scope.include?("cards:write") &&
      status != UpholdConnection::BLOCKED &&
      status != UpholdConnection::PENDING &&
      !publisher.excluded_from_payout
  end

  def wallet
    @wallet ||= publisher&.wallet
  end

  def create_uphold_cards
    return unless can_create_uphold_cards? && default_currency.present?

    CreateUpholdCardsJob.perform_later(uphold_connection_id: id)

    publisher.channels.each do |channel|
      CreateUpholdChannelCardJob.perform_later(uphold_connection_id: id, channel_id: channel.id)
    end
  end

  def missing_card?
    (default_currency_confirmed_at.present? && address.blank?) || !valid_card?
  end

  # Public: Returns a list of supported currencies for a publisher
  #
  # Returns an array of currencies
  def supported_currencies
    uphold_details&.currencies
  end

  # Calls the Uphold API and checks
  #   - if the address exists
  #   - the card is in the same currency as the publisher's chosen currency
  #
  # Returns true if the checks pass, returns false if the Uphold API returns a 404 Not Found, or the address doesn't exist.
  def valid_card?
    return false if address.blank?

    card = UpholdClient.card.find(
      uphold_connection: self,
      id: address
    )

    card&.currency.eql?(default_currency)
  rescue Faraday::ResourceNotFound
    false
  rescue Faraday::ClientError
    # We'll get an HTTP Status 403 when the User doesn't have access to create cards
    # or the access_token has expired.
    false
  end

  # Makes an HTTP Request to Uphold and sychronizes
  def sync_connection!
    # Set uphold_details to a variable, if uphold_access_parameters is nil
    # we will end up makes N service calls everytime we call uphold_details
    # this is a side effect of the memoization
    uphold_information = uphold_details
    return if uphold_information.blank?

    update(
      is_member: uphold_information.memberAt.present?,
      member_at: uphold_information.memberAt,
      status: uphold_information.status,
      uphold_id: uphold_information.id,
      country: uphold_information.country
    )
  end

  def update_site_banner_lookup!
    publisher.update_site_banner_lookup!
  end

  # Internal: If the publisher previously had referral codes and then we will re-activate their referral codes.
  #
  # Returns nil
  def update_promo_status
    publisher.update_promo_status!
  end

  def japanese_account?
    country == JAPAN
  end

  def currencies
    return if uphold_details.blank?
    uphold_details&.currencies
  end

  class << self
    def encryption_key(key: Rails.application.secrets[:attr_encrypted_key])
      # Truncating the key due to legacy OpenSSL truncating values to 32 bytes.
      # New implementations should use [Rails.application.secrets[:attr_encrypted_key]].pack("H*")
      key.byteslice(0, 32)
    end
  end

  private

  def send_blocked_message
    SlackMessenger.new(message: "Publisher #{id} is blocked by Uphold and has just logged in. <!channel>", channel: SlackMessenger::ALERTS).perform
  end
end
