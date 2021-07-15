class Payout::EnqueueTopReferrerPayoutJob
  include Sidekiq::Worker
  sidekiq_options queue: :scheduler

  def perform
    EnqueuePublishersForPayoutJob.new.perform(
      publisher_ids: Publisher.with_verified_channel.in_top_referrer_program.pluck(:id)
    )
  end
end
