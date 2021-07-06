module LegacyData
  class LegacyU2fRegistration < ApplicationRecord
    belongs_to :legacy_publisher, foreign_key: :publisher_id
  end

  class LegacyTotpRegistration < ApplicationRecord
    belongs_to :legacy_publisher, foreign_key: :publisher_id
  end

  class LegacyYoutubeChannel < ApplicationRecord
  end

  class LegacyPublisher < ApplicationRecord
    belongs_to :legacy_youtube_channel, foreign_key: :youtube_channel_id
    has_many :legacy_u2f_registrations, -> { order("created_at DESC") }, foreign_key: :publisher_id
    has_one :legacy_totp_registration, foreign_key: :publisher_id

    scope :email_verified, -> {where.not(email: nil)}

    scope :verified_sites, ->(email:) {where(email: email, verified: true, youtube_channel_id: nil).where.not(brave_publisher_id: nil)}
    scope :unverified_sites, ->(email:) {where(email: email, verified: false, youtube_channel_id: nil).where.not(brave_publisher_id: nil)}

    scope :verified_youtube, ->(email:) {where(email: email, verified: true, brave_publisher_id: nil).where.not(youtube_channel_id: nil)}
  end
end