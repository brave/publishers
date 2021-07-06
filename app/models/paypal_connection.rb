class PaypalConnection < ApplicationRecord
  attr_encrypted :refresh_token, key: :encryption_key, marshal: true

  JAPAN_COUNTRY_CODE = "JP".freeze

  belongs_to :user, class_name: "Publisher", foreign_key: :user_id

  after_save :update_site_banner_lookup!, if: -> { saved_change_to_verified_account? }

  def encryption_key
    # Truncating the key due to legacy OpenSSL truncating values to 32 bytes.
    # New implementations should use [Rails.application.secrets[:attr_encrypted_key]].pack("H*")
    [Rails.application.secrets[:attr_encrypted_key]].pack("H*")
  end

  def hide!
    update(hidden: true)
  end

  def update_site_banner_lookup!
    user.update_site_banner_lookup!
  end

  def default_currency
    'YEN'
  end

  def japanese_account?
    country == JAPAN_COUNTRY_CODE
  end

  def payable?
    verified_account
  end
end
