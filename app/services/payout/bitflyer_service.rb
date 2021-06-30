module Payout
  class BitflyerService
    def self.build
      new(refresher: Bitflyer::Refresher.build, payout_utils_class: Payout::Service)
    end

    def initialize(refresher:, payout_utils_class:)
      @refresher = refresher
      @payout_utils_class = payout_utils_class
    end

    # Change to call as soon as we refactor the other services
    def perform(publisher:, payout_report:)
      payout_utils = @payout_utils_class.new(payout_report: payout_report,
                                             publisher: publisher,)

      return if payout_utils.skip_publisher?

      potential_payments = []

      connection = publisher.bitflyer_connection
      # Sync the connection
      @refresher.call(bitflyer_connection: connection)

      # We don't currently support referrals payouts for Bitflyer accounts, so
      # only payout contributions on channels. To support referrals, we'd need to
      # create a deposit_id on each connection, not just the channels
      publisher.channels.verified.each do |channel|
        if channel.channel_deposit_address.present?
          potential_payments << PotentialPayment.new(
            payout_report_id: payout_report&.id,
            name: "#{channel.publication_title}",
            amount: "0",
            fees: "0",
            publisher_id: publisher.id,
            channel_id: channel.id,
            kind: ::PotentialPayment::CONTRIBUTION,
            url: "#{channel.details.url}",
            address: channel.channel_deposit_address,
            wallet_provider_id: connection.display_name || '', # this is a hash of the account_id
            wallet_provider: ::PotentialPayment.wallet_providers['bitflyer'],
            suspended: publisher.suspended?,
            status: publisher.last_status_update&.status,
            channel_stats: channel.details.stats,
            channel_type: channel.details_type
          )
        end
      end

      unless payout_utils.should_only_notify?
        potential_payments.each do |payment|
          unless payment.save
            # If the payment couldn't save then we created a PayoutMessage
            payout_utils.create_message("Could not save the potential_payment: #{payment.errors&.full_messages&.join(', ')}")
          end
        end
      end
    end
  end
end
