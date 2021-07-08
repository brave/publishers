class PaypalConnection < ApplicationRecord
  attr_encrypted :refresh_token, key: proc { |record| record.class.encryption_key }, marshal: true

  JAPAN_COUNTRY_CODE = "JP".freeze

  belongs_to :user, class_name: "Publisher", foreign_key: :user_id

  after_save :update_site_banner_lookup!, if: -> { saved_change_to_verified_account? }

  class << self
    def encryption_key(key: Rails.application.secrets[:attr_encrypted_key])
      [key].pack("H*")
    end
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
