module Payout
  class UpholdService < Service
    def perform
      return if skip_publisher?

      potential_payments = []
      uphold_connection = @publisher.uphold_connection

      uphold_connection.sync_connection!
      if uphold_connection.missing_card?
        uphold_connection.create_uphold_cards
        # Reload the connection because create_uphold_cards modifies the database records.
        uphold_connection.reload
      end

      uphold_connection.address.nil?

      # Create the referral payment for the owner
      potential_payments << PotentialPayment.new(
        payout_report_id: @payout_report&.id,
        name: @publisher.name,
        amount: "0",
        fees: "0",
        publisher_id: @publisher.id,
        kind: ::PotentialPayment::REFERRAL,
        address: "#{uphold_connection.address}",
        uphold_status: uphold_connection.status,
        reauthorization_needed: uphold_connection.uphold_access_parameters.blank?,
        uphold_member: uphold_connection.is_member?,
        uphold_id: uphold_connection.uphold_id,
        wallet_provider_id: uphold_connection.uphold_id,
        wallet_provider: ::PotentialPayment.wallet_providers['uphold'],
        suspended: @publisher.suspended?,
        status: @publisher.last_status_update&.status
      )

      # Create potential payments for channel contributions
      @publisher.channels.verified.each do |channel|
        potential_payments << PotentialPayment.new(
          payout_report_id: @payout_report&.id,
          name: "#{channel.publication_title}",
          amount: "0",
          fees: "0",
          publisher_id: @publisher.id,
          channel_id: channel.id,
          kind: ::PotentialPayment::CONTRIBUTION,
          address: "#{uphold_connection.address}",
          url: "#{channel.details.url}",
          uphold_status: uphold_connection.status,
          reauthorization_needed: uphold_connection.uphold_access_parameters.blank?,
          uphold_member: uphold_connection.is_member?,
          uphold_id: uphold_connection.uphold_id,
          wallet_provider_id: uphold_connection.uphold_id,
          wallet_provider: ::PotentialPayment.wallet_providers['uphold'],
          suspended: @publisher.suspended?,
          status: @publisher.last_status_update&.status,
          channel_stats: channel.details.stats,
          channel_type: channel.details_type
        )
      end

      unless should_only_notify?
        potential_payments.each do |payment|
          unless payment.save
            # If the payment couldn't save then we created a PayoutMessage
            PayoutMessage.create(
              payout_report: @payout_report,
              publisher: @publisher,
              message: "Could not save the potential_payment: #{payment.errors&.full_messages&.join(', ')}"
            )
          end
        end
      end

    rescue StandardError => e
      PayoutMessage.create(payout_report: @payout_report, publisher: @publisher, message: e.message) unless should_only_notify?
      raise e
    end
  end
end
