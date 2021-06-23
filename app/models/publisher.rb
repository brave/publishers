require 'digest/md5'

class Publisher < ApplicationRecord
  include UserFeatureFlags
  include ReferralPromo

  has_paper_trail only: [:name, :email, :pending_email, :last_sign_in_at, :default_currency, :role, :excluded_from_payout]
  self.per_page = 20

  ADMIN = "admin".freeze
  PARTNER = "partner".freeze
  PUBLISHER = "publisher".freeze
  BROWSER_USER = "browser_user".freeze

  UPHOLD_CONNECTION = UpholdConnection.to_s
  GEMINI_CONNECTION = GeminiConnection.to_s
  BITFLYER_CONNECTION = BitflyerConnection.to_s

  ROLES = [ADMIN, PARTNER, PUBLISHER, BROWSER_USER].freeze

  VERIFIED_CHANNEL_COUNT = :verified_channel_count
  ADVANCED_SORTABLE_COLUMNS = [VERIFIED_CHANNEL_COUNT].freeze

  OWNER_PREFIX = "publishers#uuid:".freeze

  devise :timeoutable, :trackable, :omniauthable

  has_many :u2f_registrations, -> { order("created_at DESC") }
  has_one :totp_registration
  has_one :two_factor_authentication_removal
  has_one :user_authentication_token, foreign_key: :user_id
  has_one :case
  has_one :paypal_connection, -> { where(hidden: false) }, foreign_key: :user_id, class_name: "PaypalConnection"
  has_many :login_activities

  has_many :channels, validate: true, autosave: true
  has_many :promo_registrations, dependent: :destroy
  has_many :promo_campaigns, dependent: :destroy
  has_many :site_banners
  has_many :site_channel_details, through: :channels, source: :details, source_type: 'SiteChannelDetails'
  has_many :youtube_channel_details, through: :channels, source: :details, source_type: 'YoutubeChannelDetails'
  has_many :status_updates, -> { order(created_at: :desc) }, class_name: 'PublisherStatusUpdate'
  has_many :whitelist_updates, -> { order(created_at: :desc) }, class_name: 'PublisherWhitelistUpdate'
  has_many :notes, class_name: 'PublisherNote', dependent: :destroy
  has_many :potential_payments
  has_many :invoices

  belongs_to :youtube_channel
  belongs_to :selected_wallet_provider, polymorphic: true
  belongs_to :uphold_for_join, foreign_key: :selected_wallet_provider_id, class_name: UPHOLD_CONNECTION # rubocop:disable Rails/ReflectionClassName
  belongs_to :gemini_for_join, foreign_key: :selected_wallet_provider_id, class_name: GEMINI_CONNECTION # rubocop:disable Rails/ReflectionClassName
  belongs_to :bitflyer_for_join, foreign_key: :selected_wallet_provider_id, class_name: BITFLYER_CONNECTION # rubocop:disable Rails/ReflectionClassName

  has_one :uphold_connection
  has_one :stripe_connection
  has_one :gemini_connection
  has_one :bitflyer_connection

  belongs_to :created_by, class_name: "Publisher"
  has_many :created_users, class_name: "Publisher",
                           foreign_key: "created_by_id"

  attr_encrypted :authentication_token, key: :encryption_key

  attribute :subscribed_to_marketing_emails, :boolean, default: false # (Albert Wang): We will use this as a flag for whether or not marketing emails are on for the user.
  validates :email, email: true, presence: true, unless: -> { pending_email.present? || deleted? || browser_user? }
  validates :pending_email, email: { strict_mode: true }, presence: true, allow_nil: true, if: -> { !(deleted? || browser_user?) }
  validate :pending_email_must_be_a_change, unless: -> { deleted? || browser_user? }
  validate :pending_email_can_not_be_in_use, unless: -> { deleted? || browser_user? }

  validates :name, presence: true, allow_blank: true, length: { maximum: 64 }
  before_save :cleanup_name, if: -> { name_changed? }

  validates_inclusion_of :role, in: ROLES

  before_create :build_default_channel, :set_default_features
  before_destroy :dont_destroy_publishers_with_channels

  scope :by_email_case_insensitive, -> (email_to_find) { where('lower(publishers.email) = :email_to_find', email_to_find: email_to_find&.downcase) }
  scope :by_pending_email_case_insensitive, -> (email_to_find) { where('lower(publishers.pending_email) = :email_to_find', email_to_find: email_to_find&.downcase) }

  after_create :set_created_status
  after_update :set_onboarding_status, if: -> { email.present? && email_before_last_save.nil? }
  after_update :set_active_status, if: -> { saved_change_to_two_factor_prompted_at? && two_factor_prompted_at_before_last_save.nil? }

  scope :created_recently, -> { where("created_at > :start_date", start_date: 1.week.ago) }

  scope :email_verified, -> { where.not(email: nil) }
  scope :admin, -> { where(role: ADMIN) }
  scope :not_admin, -> { where.not(role: ADMIN) }
  scope :partner, -> { where(role: PARTNER) }
  scope :not_partner, -> { where.not(role: PARTNER) }

  scope :created, -> { filter_status(PublisherStatusUpdate::CREATED) }
  scope :onboarding, -> { filter_status(PublisherStatusUpdate::ONBOARDING) }
  scope :suspended, -> { filter_status(PublisherStatusUpdate::SUSPENDED) }
  scope :locked, -> { filter_status(PublisherStatusUpdate::LOCKED) }
  scope :deleted, -> { filter_status(PublisherStatusUpdate::DELETED) }
  scope :no_grants, -> { filter_status(PublisherStatusUpdate::NO_GRANTS) }
  scope :hold, -> { filter_status(PublisherStatusUpdate::HOLD) }
  scope :only_user_funds, -> { filter_status(PublisherStatusUpdate::ONLY_USER_FUNDS) }

  scope :not_suspended, -> {
    where.not(id: suspended)
  }

  scope :with_verified_channel, -> {
    joins(:channels).where('channels.verified = true').distinct
  }

  store_accessor :feature_flags, VALID_FEATURE_FLAGS

  def self.valid_payable_uphold_creators
    where(selected_wallet_provider_type: UPHOLD_CONNECTION)
    where('uphold_connections.country IS NULL').
      or(
        where(selected_wallet_provider_type: UPHOLD_CONNECTION).
        where.not("uphold_connections.country ILIKE '#{UpholdConnection::JAPAN}'")
      ).
      joins(:uphold_for_join)
  end

  def self.valid_payable_gemini_creators
    where(selected_wallet_provider_type: GEMINI_CONNECTION).
      where('gemini_connections.country IS NULL').
      or(
        where(selected_wallet_provider_type: GEMINI_CONNECTION).
        where.not("gemini_connections.country ILIKE '#{GeminiConnection::JAPAN}'")
      ).
      joins(:gemini_for_join)
  end

  def self.valid_payable_bitflyer_creators
    joins(:bitflyer_for_join).
      where(selected_wallet_provider_type: BITFLYER_CONNECTION)
  end

  def self.filter_status(status)
    joins(:status_updates).
      where('publisher_status_updates.created_at =
            (SELECT MAX(publisher_status_updates.created_at)
            FROM publisher_status_updates
            WHERE publisher_status_updates.publisher_id = publishers.id)').
      where("publisher_status_updates.status = ?", status)
  end

  # Because the status_updates wasn't backfilled we also include those who have no status to be "Active"
  def self.active
    joins('LEFT OUTER JOIN publisher_status_updates ON publisher_status_updates.publisher_id = publishers.id').
      where('publisher_status_updates.created_at =
            (
              SELECT MAX(publisher_status_updates.created_at)
              FROM publisher_status_updates
              WHERE publisher_status_updates.publisher_id = publishers.id
            ) OR
            publisher_status_updates.publisher_id is NULL').
      where("publisher_status_updates.status = ? OR publisher_status_updates.status is NULL", PublisherStatusUpdate::ACTIVE)
  end

  def self.statistical_totals(up_to_date: 1.day.from_now)
    # TODO change this
    {
      email_verified_with_a_verified_channel_and_uphold_kycd: Publisher.joins(:uphold_connection).where(role: Publisher::PUBLISHER, 'uphold_connections.is_member': true).email_verified.joins(:channels).where(channels: { verified: true }).where("channels.verified_at <= ? or channels.verified_at is null", up_to_date).where("channels.created_at <= ?", up_to_date).distinct(:id).count,
      email_verified_and_uphold_kycd: Publisher.joins(:uphold_connection).where(role: Publisher::PUBLISHER, 'uphold_connections.is_member': true).email_verified.distinct(:id).count,
      email_verified_with_a_verified_channel_and_uphold_verified: Publisher.joins(:uphold_connection).where(role: Publisher::PUBLISHER, 'uphold_connections.uphold_verified': true).email_verified.joins(:channels).where(channels: { verified: true }).where("channels.verified_at <= ? or channels.verified_at is null", up_to_date).where("channels.created_at <= ?", up_to_date).distinct(:id).count,
      email_verified_with_a_verified_channel: Publisher.where(role: Publisher::PUBLISHER).email_verified.joins(:channels).where(channels: { verified: true }).where("channels.verified_at <= ? or channels.verified_at is null", up_to_date).where("channels.created_at <= ?", up_to_date).distinct(:id).count,
      email_verified_with_a_channel: Publisher.where(role: Publisher::PUBLISHER).email_verified.joins(:channels).where("channels.created_at <= ?", up_to_date).distinct(:id).count,
      email_verified: Publisher.where(role: Publisher::PUBLISHER).email_verified.where("created_at <= ?", up_to_date).distinct(:id).count,
    }
  end

  def authentication_token
    user_authentication_token&.authentication_token
  end

  def authentication_token_expires_at
    user_authentication_token&.authentication_token_expires_at
  end

  def self.advanced_sort(column, sort_direction)
    # Please update ADVANCED_SORTABLE_COLUMNS
    case column
    when VERIFIED_CHANNEL_COUNT
      Publisher.
        where(role: Publisher::PUBLISHER).
        left_joins(:channels).
        where(channels: { verified: true }).
        group(:id).
        select("publishers.*", "count(channels.id) channels_count").
        order(sanitize_sql_for_order("channels_count #{sort_direction}"))
    end
  end

  # API call to eyeshade
  def wallet
    @wallet ||= PublisherWalletGetter.new(publisher: self, include_transactions: false).perform
  end

  # Public: Checks the different wallet connections and enqueues sync jobs to refresh their data
  #         If their data wasn't refreshed in the last 2 hours.
  #
  # Returns nil
  def sync_wallet_connections
    if gemini_connection.present? && gemini_connection.updated_at < 2.hours.ago
      Sync::Connection::GeminiConnectionSyncJob.perform_later(publisher_id: id)
    end

    if uphold_connection.present? && uphold_connection.updated_at < 2.hours.ago
      Sync::Connection::UpholdConnectionSyncJob.perform_later(publisher_id: id)
    end
  end

  def is_selected_wallet_provider_uphold?
    selected_wallet_provider_type == UPHOLD_CONNECTION
  end

  def encryption_key
    Publisher.encryption_key
  end

  def email_verified?
    email.present?
  end

  # Silly method for showing a color for people's avatar
  def avatar_color
    Digest::MD5.hexdigest(email || pending_email)[0...6]
  end

  # Public: Show history of publisher's notes and statuses sorted by the created time
  #
  # Returns an array of PublisherNote and PublisherStatusUpdate
  def history
    # Create hash with created_at time as the key
    # Then we can merge and sort by the key to get history
    notes = self.notes.where(thread_id: nil)
    status = status_updates.map { |s| { s.created_at => s } }

    statuses_with_notes = status_updates.select { |s| s.publisher_note_id.present? }.map(&:publisher_note_id)
    notes = notes.to_a.delete_if { |n| statuses_with_notes.include?(n.id) }

    notes.map! { |n| { n.created_at => n } }

    combined = notes + status + case_history
    combined = combined.sort { |x, y| x.keys.first <=> y.keys.first }.reverse

    combined.map { |c| c.values.first }
  end

  def case_history
    return [] if self.case.blank?
    case_number = self.case.number

    self.case.versions.map do |c|
      # Dynamically add the case_number to this
      class << c
        attr_accessor :number
      end
      c.number = case_number

      { c.created_at => c }
    end
  end

  def deleted?
    last_status_update&.status == PublisherStatusUpdate::DELETED
  end

  def suspended?
    last_status_update&.status == PublisherStatusUpdate::SUSPENDED
  end

  def no_grants?
    last_status_update&.status == PublisherStatusUpdate::NO_GRANTS
  end

  def hold?
    last_status_update&.status == PublisherStatusUpdate::HOLD
  end

  def only_user_funds?
    last_status_update&.status == PublisherStatusUpdate::ONLY_USER_FUNDS
  end

  def locked?
    last_status_update&.status == PublisherStatusUpdate::LOCKED
  end

  def verified?
    email_verified? && name.present? && agreed_to_tos.present?
  end

  def to_s
    name || email
  end

  def owner_identifier
    "#{OWNER_PREFIX}#{id}"
  end

  def has_verified_channel?
    channels.any?(&:verified?)
  end

  def admin?
    role == ADMIN
  end

  def partner?
    role == PARTNER
  end

  def publisher?
    role == PUBLISHER
  end

  def browser_user?
    role == BROWSER_USER
  end

  def default_site_banner
    site_banners.detect { |sb| sb.id == default_site_banner_id }
  end

  def update_site_banner_lookup!
    channels.verified.find_each do |channel|
      channel.update_site_banner_lookup!
    end
  end

  def inferred_status
    return last_status_update.status if last_status_update.present?
    if verified?
      return PublisherStatusUpdate::ACTIVE
    else
      return PublisherStatusUpdate::ONBOARDING
    end
  end

  def last_status_update
    status_updates.first
  end

  def last_whitelist_update
    whitelist_updates.first
  end

  def last_login_activity
    login_activities.last
  end

  def register_for_2fa_removal
    TwoFactorAuthenticationRemoval.create(
      publisher_id: id
    )
  end

  def registered_for_2fa_removal?
    two_factor_authentication_removal.present?
  end

  # Remove when new dashboard is finished
  def in_new_ui_whitelist?
    partner?
  end

  def timeout_in
    return 2.hours if admin?
    thirty_day_login? ? 30.days : 30.minutes
  end

  def bitflyer_locale?(locale)
    locale == 'ja'
  end

  def last_supported_login_locale
    # If we update here, we should also update RegistrationsController.locale_from_header
    locale = last_login_activity.accept_language.first(2)
    case locale
    when 'ja'
      :ja
    else
      I18n.default_locale
    end
  rescue
    I18n.default_locale
  end

  def brave_payable?
    selected_wallet_provider&.payable?
  end

  def country
    provider_country = selected_wallet_provider&.country

    provider_country.to_s.upcase
  end

  def bitflyer_enabled?
    feature_flags["bitflyer_enabled"] == true
  end

  private

  def cleanup_name
    [".", ":", "/"].each do |char|
      self.name = name.gsub(char, "")
    end
  end

  # Internal: Sets the default feature flags for an account
  #
  # Returns true
  def set_default_features
    feature_flags[UserFeatureFlags::REFERRAL_KYC_REQUIRED] = true
    feature_flags[UserFeatureFlags::GEMINI_ENABLED] = true
    feature_flags[UserFeatureFlags::BITFLYER_ENABLED] = true
  end

  def set_created_status
    created_publisher_status_update = PublisherStatusUpdate.new(publisher: self, status: "created")
    created_publisher_status_update.save!
  end

  def set_onboarding_status
    onboarding_publisher_status_update = PublisherStatusUpdate.new(publisher: self, status: "onboarding")
    onboarding_publisher_status_update.save!
  end

  def set_active_status
    if two_factor_prompted_at.nil? || agreed_to_tos.nil?
      raise "Publisher must have agreed to TOS and addressed 2fa prompt to be active"
    else
      active_publisher_status_update = PublisherStatusUpdate.new(publisher: self, status: "active")
      active_publisher_status_update.save!
    end
  end

  def dont_destroy_publishers_with_channels
    if channels.count > 0
      errors.add(:base, "cannot delete publisher while channels exist")
      throw :abort
    end
  end

  def build_default_channel
    channel = Channel.new
    channel.publisher = self
    true
  end

  def pending_email_must_be_a_change
    if pending_email == email
      errors.add(:pending_email, "is not a change")
    end
  end

  def pending_email_can_not_be_in_use
    if pending_email && Publisher.by_email_case_insensitive(pending_email).first.present?
      errors.add(:pending_email, "is taken")
    end
  end

  class << self
    def encryption_key
      # Truncating the key due to legacy OpenSSL truncating values to 32 bytes.
      # New implementations should use [Rails.application.secrets[:attr_encrypted_key]].pack("H*")
      Rails.application.secrets[:attr_encrypted_key].byteslice(0, 32)
    end

    def find_by_owner_identifier(owner_identifier)
      Publisher.find(owner_identifier.split(OWNER_PREFIX)[1])
    end
  end
end
