require "test_helper"
require "webmock/minitest"

class GeminiServiceTest < ActiveJob::TestCase
  include MockGeminiResponses
  let(:payout_report) { PayoutReport.create(expected_num_payments: PayoutReport.expected_num_payments(Publisher.all)) }

  let(:subject) do
    perform_enqueued_jobs do
      Payout::GeminiService.new(
        payout_report: payout_report,
        publisher: publisher,
        should_send_notifications: true
      ).perform
    end
  end

  before do
    ActionMailer::Base.deliveries.clear
    PotentialPayment.destroy_all
  end

  describe "when publisher does not have a verified channel" do
    let(:publisher) { publishers(:fake1) }

    before { subject }

    it "does not generate a report" do
      assert_equal 0, PotentialPayment.count
    end
  end

  describe "when publisher is suspended" do
    let(:publisher) { publishers(:gemini_suspended) }

    before { subject }

    it 'marks the potential payment as suspended' do
      PotentialPayment.all.each { |pp| assert_equal "suspended", pp.status }
    end
  end

  describe 'when a gemini connection is not verified' do
    let(:publisher) { publishers(:gemini_not_completed_no_address) }

    before do
      mock_gemini_unverified_account_request!
      subject
    end

    it 'creates no Potential Payments' do
      assert_equal PotentialPayment.count, 0
    end
  end

  describe 'when a gemini connection is not verified' do
    let(:publisher) { publishers(:gemini_not_completed) }

    before do
      mock_gemini_account_request!
      mock_gemini_recipient_id!
      subject
    end

    it 'creates potential payments for the right publisher' do
      refute_equal PotentialPayment.count, 0
      PotentialPayment.all.each { |pp| assert_equal publisher.id, pp.publisher_id }
    end

    it 'has all payments marked as verified' do
      PotentialPayment.all.each { |pp| assert pp.gemini_is_verified }
    end

    it 'the address is the recipient id' do
      PotentialPayment.all.each { |pp| assert_equal pp.wallet_provider_id, publisher.selected_wallet_provider.referral_deposit_address }
    end
  end
end
