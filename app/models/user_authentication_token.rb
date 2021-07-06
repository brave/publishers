class UserAuthenticationToken < ApplicationRecord
  attr_encrypted :authentication_token, key: :encryption_key
  belongs_to :user, class_name: "Publisher", foreign_key: :user_id

  def encryption_key
    UserAuthenticationToken.encryption_key
  end

  class << self
    def encryption_key
      # Truncating the key due to legacy OpenSSL truncating values to 32 bytes.
      # New implementations should use [Rails.application.secrets[:attr_encrypted_key]].pack("H*")
      Rails.application.secrets[:attr_encrypted_key].byteslice(0, 32)
    end
  end
end
