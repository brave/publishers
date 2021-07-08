# frozen_string_literal: true

class BitflyerConnection < ApplicationRecord
  include WalletProviderProperties
  SUPPORTED_CURRENCIES = ["BAT", "USD", "BTC", "ETH"].freeze
  JAPAN = "JP"

  has_paper_trail

  belongs_to :publisher
  attr_encrypted :access_token, :refresh_token, key: proc { |record| record.class.encryption_key }
  validates :recipient_id, uniqueness: true, allow_blank: true
  validates :default_currency, inclusion: { in: SUPPORTED_CURRENCIES }, allow_nil: true

  def prepare_state_token!
    update(state_token: SecureRandom.hex(64).to_s)
  end

  def payable?
    true
  end

  def japanese_account?
    country&.upcase == JAPAN
  end

  def verify_url
    ""
  end

  # Public: All the support currency pairs for BAT on the Bitflyer Exchange
  # https://bitflyer.com/en-us/api
  #
  # Returns an array of currencies.
  def supported_currencies
    SUPPORTED_CURRENCIES
  end

  def access_token_expired?
    access_expiration_time.present? && Time.now > access_expiration_time
  end

  def sync_connection!
    return if access_token.blank?

    # If our access token has expired then we should refresh.
    if access_token_expired?
      refresh_authorization!
    end

    users = Bitflyer::Account.find(token: access_token).users
    user = users.find { |u| u.is_verified && u.status == 'Active' }

    # If we couldn't find a verified account we'll take the first user.
    user ||= users.first

    update(
      display_name: user.name,
      status: user.status,
      country: user.country_code,
      is_verified: user.is_verified,
    )

    # Users aren't able to create a recipient id if they are not fully verified
    if payable?
      return true
    end
  end

  class << self
    def encryption_key(key: Rails.application.secrets[:attr_encrypted_key])
      [key].pack("H*")
    end
  end
end
