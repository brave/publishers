class Payout::Service::RetriesFromLastEnqueuedPublisher
  def self.enqueue_retryable_potential_payout!(
    klass_name:,
    kind:,
    payout_report_id:,
    publisher_ids:,
    publishers:,
    should_send_notifications:
  )
    # The retryable key would be something like Payout::BitflyerJob-abcdef0-1234-4567-8901
    last_enqueued_publisher_key = "#{klass_name}-#{payout_report_id || ""}"
    last_enqueued_publisher_id = Rails.cache.fetch(last_enqueued_publisher_key)

    if publisher_ids.present?
      publishers = publishers.where(id: publisher_ids)
    elsif kind == IncludePublisherInPayoutReportJob::MANUAL
      publishers = publishers.invoice
    else
      publishers = publishers.with_verified_channel.not_in_top_referrer_program
    end

    publishers = publishers.where("publishers.id > ?", last_enqueued_publisher_id) if last_enqueued_publisher_id.present?

    if payout_report_id.present?
      payout_report = PayoutReport.find(payout_report_id)
      if last_enqueued_publisher_id.nil? # don't retry after 1st write
        number_of_payments = PayoutReport.expected_num_payments(publishers)
        payout_report.with_lock do
          payout_report.reload
          payout_report.expected_num_payments = number_of_payments + payout_report.expected_num_payments
          payout_report.save!
        end
      end
    end

    publishers.find_each do |publisher|
      IncludePublisherInPayoutReportJob.perform_async(
        payout_report_id: payout_report_id,
        publisher_id: publisher.id,
        kind: kind,
        should_send_notifications: @should_send_notifications
      )
      Rails.cache.write(last_enqueued_publisher_key, publisher.id.to_s, expires_in: 72.hours)
    end
  end
end
