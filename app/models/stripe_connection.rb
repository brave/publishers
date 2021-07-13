# frozen_string_literal: true

class StripeConnection < ApplicationRecord
  belongs_to :publisher

  attr_encrypted :access_token, :refresh_token, key: proc { |record| record.class.encryption_key }

  def prepare_state_token!
    update(state_token: SecureRandom.hex(64).to_s)
  end

  class << self
    def encryption_key(key: Rails.application.secrets[:attr_encrypted_key])
      [key].pack("H*")
    end
  end
end
