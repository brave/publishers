require "test_helper"
require "webmock/minitest"

class Promo::RegistrationsStatsFetcherTest < ActiveJob::TestCase
  include PromosHelper

  before(:example) do
    @prev_promo_api_uri = Rails.application.secrets[:api_promo_base_uri]
  end

  after(:example) do
    Rails.application.secrets[:api_promo_base_uri] = @prev_promo_api_uri
  end

  test "saves the stats" do
    # ensure an external request is attempted to be stubbed by turning on promo
    Rails.application.secrets[:api_promo_base_uri] = "http://127.0.0.1:8194"

    # create two registrations
    PromoRegistration.create(promo_id: active_promo_id, referral_code: "ABC123", kind: PromoRegistration::UNATTACHED)
    PromoRegistration.create(promo_id: active_promo_id, referral_code: "DEF456", kind: PromoRegistration::UNATTACHED)

    # stub the response body
    stubbed_response_body = [
      {
        "referral_code" => "ABC123",
        "ymd" => "2018-04-29",
        "retrievals" => 0,
        "first_runs" => 1,
        "finalized" => 1,
      },
      {
        "referral_code" => "ABC123",
        "ymd" => "2018-05-12",
        "retrievals" => 0,
        "first_runs" => 1,
        "finalized" => 0,
      },
      {
        "referral_code" => "DEF456",
        "ymd" => "2018-06-17",
        "retrievals" => 0,
        "first_runs" => 1,
        "finalized" => 0,
      },
    ].to_json

    request_url = "#{Rails.application.secrets[:api_promo_base_uri]}/api/2/promo/statsByReferralCode?referral_code=ABC123&referral_code=DEF456"
    stub_request(:get, request_url).
      to_return(status: 200, body: stubbed_response_body)

    promo_registrations = PromoRegistration.where(referral_code: ["ABC123", "DEF456"])
    Promo::RegistrationsStatsFetcher.new(promo_registrations: promo_registrations).perform

    assert_equal 2, PromoRegistration.find_by_referral_code("ABC123").aggregate_stats[PromoRegistration::FIRST_RUNS]
    assert_equal 1, PromoRegistration.find_by_referral_code("DEF456").aggregate_stats[PromoRegistration::FIRST_RUNS]
  end

  test "makes the request in batches if > 100 codes" do
    Rails.application.secrets[:api_promo_base_uri] = "http://127.0.0.1:8194"
    number_of_codes_needed = 200 - PromoRegistration.count

    # Insert ~200 referral codes
    sql_values = ""
    number_of_codes_needed.times do
      sql_values += "('#{SecureRandom.hex(8)}', '#{active_promo_id}', '#{PromoRegistration::UNATTACHED}','#{Time.now}', '#{Time.now}'),"
    end
    sql_values = sql_values.chomp(",")

    sql = "INSERT into promo_registrations (referral_code, promo_id, kind, created_at, updated_at) values #{sql_values}"
    ActiveRecord::Base.connection.execute(sql)

    assert_equal PromoRegistration.count, 200

    promo_stats_service = Promo::RegistrationsStatsFetcher.new(promo_registrations: PromoRegistration.all)
    # stub response for first 50
    PromoRegistration.in_batches(of: Promo::RegistrationsStatsFetcher::BATCH_SIZE) do |slice|
      batch_query_string = promo_stats_service.send(:query_string, slice)
      batch_response = []
      slice.each do |promo_registration|
        batch_response.push({
          "referral_code" => "#{promo_registration.referral_code}",
          "ymd" => "2018-04-29",
          "retrievals" => 5,
          "first_runs" => 0,
          "finalized" => 0,
        })
      end
      request_url = "#{Rails.application.secrets[:api_promo_base_uri]}/api/2/promo/statsByReferralCode#{batch_query_string}"
      stub_request(:get, request_url).to_return(status: 200, body: batch_response.to_json)
    end

    # ensure PromoRegistration.count / BATCH_SIZE requests were made
    promo_stats_service.perform

    PromoRegistration.in_batches(of: Promo::RegistrationsStatsFetcher::BATCH_SIZE) do |slice|
      slice.each do |promo_registration|
        assert_equal PromoRegistration.find_by_referral_code(promo_registration.referral_code).aggregate_stats[PromoRegistration::RETRIEVALS], 5
      end
    end
  end
end
