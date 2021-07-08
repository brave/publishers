class UserAuthenticationToken < ApplicationRecord
  attr_encrypted :authentication_token, key: proc { |record| record.class.encryption_key }
  belongs_to :user, class_name: "Publisher", foreign_key: :user_id

  class << self
    def encryption_key(key: Rails.application.secrets[:attr_encrypted_key])
      # Truncating the key due to legacy OpenSSL truncating values to 32 bytes.
      # New implementations should use [Rails.application.secrets[:attr_encrypted_key]].pack("H*")
      key.byteslice(0, 32)
    end
  end
end
