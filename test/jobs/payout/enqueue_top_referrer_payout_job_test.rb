require 'test_helper'

class EnqueueTopReferrerPayoutJobTest < ActiveJob::TestCase
  test 'it enqueues only top referrers to to call EnqueuePublishersForPayoutJob' do
    Sidekiq::Worker.clear_all
    Payout::EnqueueTopReferrerPayoutJob.new.perform
    assert_equal 1, Payout::UpholdJob.jobs.count
    top_publisher_ids = Publisher.with_verified_channel.in_top_referrer_program.pluck(:id)
    job = Payout::UpholdJob.jobs.first
    assert_equal JSON.parse(job["args"].first)["publisher_ids"], top_publisher_ids

    Payout::UpholdJob.new.perform(job["args"].first)

    assert IncludePublisherInPayoutReportJob.jobs.count >= 1
    top_publisher_ids = Publisher.with_verified_channel.in_top_referrer_program.pluck(:id)
    IncludePublisherInPayoutReportJob.jobs.each do |job|
      assert job["args"].first["publisher_id"].in?(top_publisher_ids)
    end
  end
end
