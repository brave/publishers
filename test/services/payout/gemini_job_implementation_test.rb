# frozen_string_literal: true

require 'test_helper'

class GeminiJobImplementationTest < ActiveSupport::TestCase
  test "it doesn't include Japanese payouts" do
    gemini_in_japan = publishers(:gemini_in_japan)
    assert gemini_in_japan.selected_wallet_provider.japanese_account?
    mock_report_job = mock
    mock_report_job.expects(:perform_async).with do |*args|
      refute Publisher.find(args[0][:publisher_id]).gemini_connection.japanese_account?
    end.at_least_once
    gemini_job = Payout::GeminiJobImplementation.new(payout_report_job: mock_report_job)
    gemini_job.call
  end

  test "it doesn't include Japanese payouts when providing ids" do
    gemini_in_japan = publishers(:gemini_in_japan)
    mock_report_job = mock
    mock_report_job.expects(:perform_async).never
    gemini_job = Payout::GeminiJobImplementation.new(payout_report_job: mock_report_job)
    gemini_job.call(publisher_ids: [gemini_in_japan.id])
  end
end
