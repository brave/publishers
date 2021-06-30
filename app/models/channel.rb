require "publishers/restricted_channels"

class Channel < ApplicationRecord
  include ChannelProperties

  has_paper_trail

  CONTEST_TIMEOUT = 10.days

  YOUTUBE_VIEW_COUNT = :youtube_view_count
  TWITCH_VIEW_COUNT = :twitch_view_count
  FOLLOWER_COUNT = :follower_count
  VIDEO_COUNT = :video_count
  SUBSCRIBER_COUNT = :subscriber_count
  ADVANCED_SORTABLE_COLUMNS = [YOUTUBE_VIEW_COUNT, TWITCH_VIEW_COUNT, VIDEO_COUNT, SUBSCRIBER_COUNT, FOLLOWER_COUNT].freeze
  BITFLYER_CONNECTION = "BitflyerConnection".freeze

  belongs_to :publisher
  belongs_to :details, polymorphic: true, validate: true, autosave: true, optional: false, dependent: :delete

  # Defined in app/models/concerns/channel_properties
  has_property :youtube
  has_property :twitch
  has_property :twitter
  has_property :vimeo
  has_property :reddit
  has_property :github

  has_one :promo_registration, dependent: :destroy
  has_many :uphold_connection_for_channel

  has_one :contesting_channel, class_name: "Channel", foreign_key: 'contested_by_channel_id'

  has_one :site_banner, dependent: :destroy
  has_one :site_banner_lookup, dependent: :destroy

  has_many :potential_payments

  belongs_to :contested_by_channel, class_name: "Channel"

  accepts_nested_attributes_for :details

  validates :publisher, presence: true

  validates :details, presence: true

  validate :details_not_changed?

  validates :verification_status, inclusion: { in: %w(failed awaiting_admin_approval approved_by_admin) }, allow_nil: true

  validates :verification_details, inclusion: {
    in: %w(domain_not_found connection_failed too_many_redirects timeout no_txt_records token_incorrect_dns token_not_found_dns token_not_found_public_file no_https),
  }, allow_nil: true

  validate :site_channel_details_brave_publisher_id_unique_for_publisher, if: -> { details_type == 'SiteChannelDetails' }

  validate :verified_duplicate_channels_must_be_contested, if: -> { verified? }

  after_save :notify_slack, if: -> { :saved_change_to_verified? && verified? }
  after_save :create_deposit_id

  # *ChannelDetails get autosaved from above.
  after_save :update_site_banner_lookup!, if: -> { :saved_change_to_verified? && verified? }
  after_commit :register_channel_for_promo, if: :should_register_channel_for_promo?
  after_commit :create_channel_card, if: -> { :saved_change_to_verified? && verified? }

  before_save :clear_verified_at_if_necessary

  before_destroy :preserve_contested_by_channels

  belongs_to :site_channel_details, -> {
    where(channels: { details_type: 'SiteChannelDetails' })
  }, foreign_key: 'details_id'

  scope :site_channels, -> { joins(:site_channel_details) }
  scope :other_verified_site_channels, -> (id:) { site_channels.where(verified: true).where.not(id: id) }

  # Once the verification_method has been set it shows we have presented the publisher with the token. We need to
  # ensure this site_channel will be preserved so the publisher cna come back to it.
  scope :visible_site_channels, -> {
    site_channels.where('channels.verified = true or NOT site_channel_details.verification_method IS NULL')
  }
  scope :not_visible_site_channels, -> {
    site_channels.where(verified: [false, nil]).where(site_channel_details: { verification_method: nil })
  }

  scope :visible, -> {
    left_outer_joins(:site_channel_details).
      where('(channels.verified = true or channels.verification_pending) or NOT site_channel_details.verification_method IS NULL')
  }

  scope :contested_channels_ready_to_transfer, -> {
    where.not(contested_by_channel_id: nil).where("contest_timesout_at < ?", Time.now)
  }

  scope :verified, -> { where(verified: true) }

  def self.statistical_totals
    properties = {}
    PROPERTIES.each { |p| properties[p] = Channel.verified.send("#{p}_channels").count }

    properties.merge({
      all_channels: Channel.verified.count,
      site: Channel.verified.site_channels.count,
    })
  end

  def self.duplicates
    duplicates = []

    entries = PROPERTIES.map do |channel|
      channel_id = ActiveRecord::Base.sanitize_sql("#{channel}_channel_id")
      public_send("#{channel}_channels").verified.select(channel_id).group(channel_id)
    end

    entries.map do |entry|
      entry.having("count(*) >1").each do |x, y|
        key = x.as_json.keys.detect { |z| z.include? "channel_id" }
        duplicates << x[key]
      end
    end

    duplicates.flatten
  end

  def publication_title
    details.publication_title
  end

  def details_not_changed?
    unless details_id_was.nil? || (details_id == details_id_was && details_type == details_type_was)
      errors.add(:details, "can't be changed")
    end
  end

  # NOTE This method is should only be used in referral promo logic. Use {channel}.details.channel_identifier for everything else.
  # This will return the channel_identifier without the youtube#channel: or twitch#channel: prefix
  def channel_id
    channel_type = details_type

    case channel_type
    when "TwitchChannelDetails"
      details.name
    else
      details.send("#{type_display.downcase}_channel_id")
    end
  end

  # Returns the verified channel with the given channel identifier
  # e.g.
  # Channel.find_by_channel_identifier(channel.details.channel_identifier)
  # => <Channel id: "55ecd577-0425-420f-8796-78598b06c8a0",...,>
  def self.find_by_channel_identifier(identifier)
    name, property = identifier.split("#")
    _, value = property&.split(':')

    if name == 'twitch'
      Channel.twitch_channels.verified.where("twitch_channel_details.name": value).first
    elsif PROPERTIES.include?(name)
      public_send("#{name}_channels").verified.where("#{name}_channel_details.#{name}_channel_id": value).first
    else
      visible_site_channels.where('site_channel_details.brave_publisher_id': identifier).first
    end
  end

  def promo_enabled?
    promo_registration&.referral_code&.present?
  end

  def verification_failed!(details = nil) # rubocop:disable Airbnb/OptArgParameters
    # Clear changes so we don't bypass validations when saving without checking them
    reload

    self.verified = false
    self.verified_at = nil
    self.verification_status = 'failed'
    self.verification_details = details
    save!
  end

  def verification_awaiting_admin_approval!
    update!(verified: false, verification_status: 'awaiting_admin_approval', verification_details: nil)
  end

  def verification_succeeded!(has_admin_approval)
    if needs_admin_approval?
      if has_admin_approval
        verification_status = "approved_by_admin"
      else
        errors.add(:base, "requires manual admin approval")
        return
      end
    else
      verification_status = nil
    end

    update!(verified: true,
            verification_pending: false,
            verification_status: verification_status,
            verification_details: nil,
            verified_at: Time.now)
  end

  def needs_admin_approval?
    Publishers::RestrictedChannels.restricted?(self)
  end

  def self.search(query)
    query = query.downcase

    base_channel = Channel.
      joins(:publisher).
      left_outer_joins(:site_channel_details).
      left_outer_joins(:youtube_channel_details).
      left_outer_joins(:twitch_channel_details)

    channel = base_channel
    query.split(' ').each do |q|
      channel = channel.
        where("lower(publishers.email) LIKE ?", q).
        or(base_channel.where("lower(publishers.name) LIKE ?", q)).
        or(base_channel.where("lower(site_channel_details.brave_publisher_id) LIKE ?", q)).
        or(base_channel.where("lower(twitch_channel_details.twitch_channel_id) LIKE ?", q)).
        or(base_channel.where("lower(twitch_channel_details.display_name) LIKE ?", q)).
        or(base_channel.where("lower(twitch_channel_details.email) LIKE ?", q)).
        or(base_channel.where("lower(youtube_channel_details.youtube_channel_id) LIKE ?", q)).
        or(base_channel.where("lower(youtube_channel_details.title) LIKE ?", q)).
        or(base_channel.where("lower(youtube_channel_details.auth_email) LIKE ?", q))
    end

    channel
  end

  def verification_failed?
    verification_status == 'failed'
  end

  def verification_awaiting_admin_approval?
    verification_status == 'awaiting_admin_approval'
  end

  def verification_approved_by_admin?
    verification_status == 'approved_by_admin'
  end

  def update_last_verification_timestamp
    # Used for caching on the api/public/channels#timestamp
    Rails.cache.set("last_updated_channel_timestamp", Time.now.to_i << 32)
  end

  def self.advanced_sort(column, sort_direction)
    # Please update ADVANCED_SORTABLE_COLUMNS
    case column
    when YOUTUBE_VIEW_COUNT
      Channel.youtube_channels.order(Arel.sql(sanitize_sql_for_order("stats->'view_count' #{sort_direction} NULLS LAST")))
    when TWITCH_VIEW_COUNT
      Channel.twitch_channels.order(Arel.sql(sanitize_sql_for_order("stats->'view_count' #{sort_direction} NULLS LAST")))
    when FOLLOWER_COUNT
      Channel.twitch_channels.order(Arel.sql(sanitize_sql_for_order("stats->'followers_count' #{sort_direction} NULLS LAST")))
    when VIDEO_COUNT
      Channel.youtube_channels.order(Arel.sql(sanitize_sql_for_order("stats->'video_count' #{sort_direction} NULLS LAST")))
    when SUBSCRIBER_COUNT
      Channel.youtube_channels.order(Arel.sql(sanitize_sql_for_order("stats->'subscriber_count' #{sort_direction} NULLS LAST")))
    end
  end

  def type_display
    details_type.split("ChannelDetails").join
  end

  def uphold_connection
    @uphold_connection ||= uphold_connection_for_channel.detect { |connection| connection.currency == publisher.uphold_connection.default_currency }
  end

  def register_channel_for_promo
    Promo::RegisterChannelForPromoJob.perform_now(channel_id: id, attempt_count: 0)
  end

  def update_site_banner_lookup!(skip_site_banner_info_lookup: false)
    return unless verified?
    site_banner_lookup = SiteBannerLookup.find_or_initialize_by(
      channel_identifier: details&.channel_identifier,
    )
    site_banner_lookup.set_sha2_base16
    site_banner_lookup.derived_site_banner_info =
      if skip_site_banner_info_lookup
        {}
      elsif publisher.default_site_banner_mode
        publisher&.default_site_banner&.non_default_properties || {}
      else
        site_banner&.non_default_properties || {}
      end
    site_banner_lookup.update!(
      channel_id: id,
      publisher_id: publisher_id,
      wallet_address: publisher&.uphold_connection&.address
    )
    site_banner_lookup.sync!
  end

  def channel_deposit_address
    selected_wallet_type = publisher.selected_wallet_provider_type
    case selected_wallet_type
    when Publisher::UPHOLD_CONNECTION
      publisher.selected_wallet_provider.referral_deposit_address
    when Publisher::GEMINI_CONNECTION
      publisher.selected_wallet_provider.referral_deposit_address
    when Publisher::BITFLYER_CONNECTION
      deposit_id
    end
  end

  private

  def should_register_channel_for_promo?
    publisher.may_create_referrals? &&
      publisher.may_register_promo? &&
      saved_change_to_verified? &&
      verified &&
      !publisher.only_user_funds?
  end

  def clear_verified_at_if_necessary
    self.verified_at = nil if verified == false && verified_at.present?
  end

  def create_channel_card
    CreateUpholdChannelCardJob.perform_later(uphold_connection_id: publisher.uphold_connection&.id, channel_id: id)
  end

  def notify_slack
    return unless verified?
    emoji =
      case details_type
      when "SiteChannelDetails"
        "🌐"
      when "TwitchChannelDetails"
        "👾"
      when "YoutubeChannelDetails"
        "📺"
      when "VimeoChannelDetails"
        "🎥"
      when "TwitterChannelDetails"
        "🐦"
      else
        ""
      end

    SlackMessenger.new(
      message: "#{emoji} *#{details.publication_title}* verified by owner #{publisher.owner_identifier}; id=#{details.channel_identifier}; url=#{details.url}"
    ).perform
  end

  # Needed for bitFlyer, but can likely be used for Uphold too.
  def create_deposit_id
    if publisher.selected_wallet_provider_type == BITFLYER_CONNECTION && deposit_id.nil?
      Sync::Bitflyer::UpdateMissingDepositJob.new.perform(id)
    end
  end

  def site_channel_details_brave_publisher_id_unique_for_publisher
    duplicate_unverified_channels = publisher.channels.visible_site_channels.
      where(site_channel_details: { brave_publisher_id: details.brave_publisher_id }).
      where.not(id: id)

    if duplicate_unverified_channels.any?
      errors.add(:brave_publisher_id, "must be unique")
    end
  end

  def preserve_contested_by_channels
    if contesting_channel || verification_pending
      errors.add(:base, "contested_by_channel cannot be destroyed")
    end
  end

  def verified_duplicate_channels_must_be_contested
    name = type_display.downcase
    if PROPERTIES.include?(name)
      duplicate_verified_channels = Channel.send("other_verified_#{name}_channels", id: id).where("#{name}_channel_details": { "#{name}_channel_id": details.send("#{name}_channel_id") })
    elsif details_type == "SiteChannelDetails"
      duplicate_verified_channels = Channel.other_verified_site_channels(id: id).where(site_channel_details: { brave_publisher_id: details.brave_publisher_id })
    end

    if duplicate_verified_channels.any?
      duplicate_verified_channels.each do |channel|
        errors.add(:base, "already exists on your account") if channel.publisher_id == publisher_id
      end

      if duplicate_verified_channels.count > 1
        errors.add(:base, "can only contest one channel")
      end

      contesting_channel = duplicate_verified_channels.first
      if (contesting_channel.contested_by_channel_id != id) && !contesting_channel.contested_by_channel_id.nil?
        errors.add(:base, "contesting channel does not match")
      end
    end
  end
end
