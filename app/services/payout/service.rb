module Payout
  class Service
    class WalletError < StandardError; end

    def initialize(payout_report:, publisher:, should_send_notifications: false)
      @publisher = publisher
      @payout_report = payout_report
      @should_send_notifications = should_send_notifications
    end

    def should_only_notify?
      @payout_report.nil?
    end

    def create_message(message)
      return if should_only_notify?

      PayoutMessage.create(
        payout_report: @payout_report,
        publisher: @publisher,
        message: "#{self.class.name} #{message}"
      )
    end

    # Internal: Creates entries for any reason for not paying out a publisher.
    #
    # Returns a boolean
    def skip_publisher?
      if !@publisher.has_verified_channel?
        create_message("Publisher has no verified channels")
        return true
      end

      if !@publisher.has_deposit_address?
        create_message("Publisher has no deposit address for wallet")
        return true
      end

      if @publisher.excluded_from_payout?
        create_message("Publisher has been marked as excluded from payout")
        return true
      end

      if @publisher.hold?
        create_message("Publisher is currently in hold status")
        return true
      end

      if @publisher.locked?
        create_message("Publisher is currently in lock status")
        return true
      end

      if @publisher.wire_only?
        create_message("Publisher is only meant to receive wire transfers")
        return true
      end

      false
    end
  end
end
