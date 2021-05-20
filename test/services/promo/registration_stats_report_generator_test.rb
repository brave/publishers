require "test_helper"

class Promo::RegistrationStatsReportGeneratorTest < ActiveJob::TestCase
  include PromosHelper

  before do
    @prev_offline = Rails.application.secrets[:api_promo_base_uri]
  end

  after do
    Rails.application.secrets[:api_promo_base_uri] = @prev_offline
  end

  STATS = [
    {
      "referral_code" => "ABC123",
      "ymd" => "2018-11-01",
      "retrievals" => 1,
      "first_runs" => 1,
      "finalized" => 1,
    },
    {
      "referral_code" => "ABC123",
      "ymd" => "2018-11-07",
      "retrievals" => 1,
      "first_runs" => 1,
      "finalized" => 1,
    },
    {
      "referral_code" => "ABC123",
      "ymd" => "2018-11-14",
      "retrievals" => 1,
      "first_runs" => 1,
      "finalized" => 1,
    },
    {
      "referral_code" => "ABC123",
      "ymd" => "2018-11-21",
      "retrievals" => 1,
      "first_runs" => 1,
      "finalized" => 1,
    },
    {
      "referral_code" => "ABC123",
      "ymd" => "2018-11-28",
      "retrievals" => 1,
      "first_runs" => 1,
      "finalized" => 1,
    },
    {
      "referral_code" => "ABC123",
      "ymd" => "2018-12-01",
      "retrievals" => 1,
      "first_runs" => 1,
      "finalized" => 1,
    },
    {
      "referral_code" => "DEF456",
      "ymd" => "2018-11-01",
      "retrievals" => 1,
      "first_runs" => 1,
      "finalized" => 1,
    },
    {
      "referral_code" => "DEF456",
      "ymd" => "2018-11-07",
      "retrievals" => 1,
      "first_runs" => 1,
      "finalized" => 1,
    },
    {
      "referral_code" => "DEF456",
      "ymd" => "2018-11-14",
      "retrievals" => 1,
      "first_runs" => 1,
      "finalized" => 1,
    },
    {
      "referral_code" => "DEF456",
      "ymd" => "2018-11-21",
      "retrievals" => 1,
      "first_runs" => 1,
      "finalized" => 1,
    },
    {
      "referral_code" => "DEF456",
      "ymd" => "2018-11-28",
      "retrievals" => 1,
      "first_runs" => 1,
      "finalized" => 1,
    },
    {
      "referral_code" => "DEF456",
      "ymd" => "2018-12-01",
      "retrievals" => 1,
      "first_runs" => 1,
      "finalized" => 1,
    },
  ].freeze

  GEO_STATS = []
  STATS.each do |stat|
    stat["country"] = "United States"
    GEO_STATS.push(stat)
    stat_mexico = stat.dup
    stat_mexico["country"] = "Mexico"
    GEO_STATS.push(stat_mexico)
  end

  test "generates report for running total without geo information" do
    Rails.application.secrets[:api_promo_base_uri] = "http://127.0.0.1:8194"
    PromoRegistration.create!(referral_code: "ABC123", kind: "unattached", promo_id: "free-bats-2018q1")
    PromoRegistration.create!(referral_code: "DEF456", kind: "unattached", promo_id: "free-bats-2018q1")

    stub_request(:get, /http:\/\/127.0.0.1:8194\/api\/2\/promo\/statsByReferralCode\?referral_code=.*/).to_return(body: STATS.to_json)

    csv = Promo::RegistrationStatsReportGenerator.new(referral_codes: ["ABC123", "DEF456"],
                                                      start_date: "2018-11-01".to_date,
                                                      end_date: "2018-12-01".to_date,
                                                      reporting_interval: PromoRegistration::RUNNING_TOTAL,
                                                      is_geo: false).perform

    expected = [
      [
        "Referral code",
        reporting_interval_column_header(PromoRegistration::RUNNING_TOTAL),
        event_type_column_header(PromoRegistration::RETRIEVALS),
        event_type_column_header(PromoRegistration::FIRST_RUNS),
        event_type_column_header(PromoRegistration::FINALIZED),
      ],
      ["ABC123", "2018-12-01", "6", "6", "6"],
      ["DEF456", "2018-12-01", "6", "6", "6"],
      [],
      ratios_column_header(false),
      ["ABC123", "6", "6", "6", "6", "1.0", "1.0"],
      ["DEF456", "6", "6", "6", "6", "1.0", "1.0"],
    ]

    assert_equal CSV.parse(csv), expected
  end

  test "generates report for running total without geo information (2)" do # earlier end_date
    Rails.application.secrets[:api_promo_base_uri] = "http://127.0.0.1:8194"
    PromoRegistration.create!(referral_code: "ABC123", kind: "unattached", promo_id: "free-bats-2018q1")
    PromoRegistration.create!(referral_code: "DEF456", kind: "unattached", promo_id: "free-bats-2018q1")

    stub_request(:get, /http:\/\/127.0.0.1:8194\/api\/2\/promo\/statsByReferralCode\?referral_code=.*/).to_return(body: STATS.to_json)
    csv = Promo::RegistrationStatsReportGenerator.new(referral_codes: ["ABC123", "DEF456"],
                                                      start_date: "2018-11-01".to_date,
                                                      end_date: "2018-11-28".to_date,
                                                      reporting_interval: PromoRegistration::RUNNING_TOTAL,
                                                      is_geo: false).perform
    expected = [
      [
        "Referral code",
        reporting_interval_column_header(PromoRegistration::RUNNING_TOTAL),
        event_type_column_header(PromoRegistration::RETRIEVALS),
        event_type_column_header(PromoRegistration::FIRST_RUNS),
        event_type_column_header(PromoRegistration::FINALIZED),
      ],
      ["ABC123", "2018-11-28", "5", "5", "5"],
      ["DEF456", "2018-11-28", "5", "5", "5"],
      [],
      ratios_column_header(false),
      ["ABC123", "5", "5", "5", "5", "1.0", "1.0"],
      ["DEF456", "5", "5", "5", "5", "1.0", "1.0"],
    ]

    assert_equal expected, CSV.parse(csv)
  end

  test "generates report for monthly without geo information" do
    Rails.application.secrets[:api_promo_base_uri] = "http://127.0.0.1:8194"
    PromoRegistration.create!(referral_code: "ABC123", kind: "unattached", promo_id: "free-bats-2018q1")
    PromoRegistration.create!(referral_code: "DEF456", kind: "unattached", promo_id: "free-bats-2018q1")

    stub_request(:get, /http:\/\/127.0.0.1:8194\/api\/2\/promo\/statsByReferralCode\?referral_code=.*/).to_return(body: STATS.to_json)

    csv = Promo::RegistrationStatsReportGenerator.new(referral_codes: ["ABC123", "DEF456"],
                                                      start_date: "2018-11-01".to_date,
                                                      end_date: "2018-12-01".to_date,
                                                      reporting_interval: PromoRegistration::MONTHLY,
                                                      is_geo: false).perform
    expected = [
      [
        "Referral code",
        reporting_interval_column_header(PromoRegistration::MONTHLY),
        event_type_column_header(PromoRegistration::RETRIEVALS),
        event_type_column_header(PromoRegistration::FIRST_RUNS),
        event_type_column_header(PromoRegistration::FINALIZED),
      ],
      ["ABC123", "2018-11-01", "5", "5", "5"],
      ["ABC123", "2018-12-01", "1", "1", "1"],
      ["DEF456", "2018-11-01", "5", "5", "5"],
      ["DEF456", "2018-12-01", "1", "1", "1"],
      [],
      ratios_column_header(false),
      ["ABC123", "6", "6", "6", "6", "1.0", "1.0"],
      ["DEF456", "6", "6", "6", "6", "1.0", "1.0"],
    ]

    assert_equal expected, CSV.parse(csv)
  end

  test "generates report for weekly without geo information" do
    Rails.application.secrets[:api_promo_base_uri] = "http://127.0.0.1:8194"
    PromoRegistration.create!(referral_code: "ABC123", kind: "unattached", promo_id: "free-bats-2018q1")
    PromoRegistration.create!(referral_code: "DEF456", kind: "unattached", promo_id: "free-bats-2018q1")

    stub_request(:get, /http:\/\/127.0.0.1:8194\/api\/2\/promo\/statsByReferralCode\?referral_code=.*/).to_return(body: STATS.to_json)

    csv = Promo::RegistrationStatsReportGenerator.new(referral_codes: ["ABC123", "DEF456"],
                                                      start_date: "2018-11-01".to_date,
                                                      end_date: "2018-11-07".to_date,
                                                      reporting_interval: PromoRegistration::WEEKLY,
                                                      is_geo: false).perform

    expected = [
      [
        "Referral code",
        reporting_interval_column_header(PromoRegistration::WEEKLY),
        event_type_column_header(PromoRegistration::RETRIEVALS),
        event_type_column_header(PromoRegistration::FIRST_RUNS),
        event_type_column_header(PromoRegistration::FINALIZED),
      ],
      ["ABC123", "2018-10-29", "1", "1", "1"],
      ["ABC123", "2018-11-05", "1", "1", "1"],
      ["DEF456", "2018-10-29", "1", "1", "1"],
      ["DEF456", "2018-11-05", "1", "1", "1"],
      [],
      ratios_column_header(false),
      ["ABC123", "2", "2", "2", "2", "1.0", "1.0"],
      ["DEF456", "2", "2", "2", "2", "1.0", "1.0"],
    ]

    assert_equal expected, CSV.parse(csv)
  end

  test "generates report for daily without geo information" do
    Rails.application.secrets[:api_promo_base_uri] = "http://127.0.0.1:8194"
    PromoRegistration.create!(referral_code: "ABC123", kind: "unattached", promo_id: "free-bats-2018q1")
    PromoRegistration.create!(referral_code: "DEF456", kind: "unattached", promo_id: "free-bats-2018q1")

    stub_request(:get, /http:\/\/127.0.0.1:8194\/api\/2\/promo\/statsByReferralCode\?referral_code=.*/).to_return(body: STATS.to_json)

    csv = Promo::RegistrationStatsReportGenerator.new(referral_codes: ["ABC123", "DEF456"],
                                                      start_date: "2018-11-01".to_date,
                                                      end_date: "2018-11-02".to_date,
                                                      reporting_interval: PromoRegistration::DAILY,
                                                      is_geo: false).perform
    expected = [
      [
        "Referral code",
        reporting_interval_column_header(PromoRegistration::DAILY),
        event_type_column_header(PromoRegistration::RETRIEVALS),
        event_type_column_header(PromoRegistration::FIRST_RUNS),
        event_type_column_header(PromoRegistration::FINALIZED),
      ],
      ["ABC123", "2018-11-01", "1", "1", "1"],
      ["ABC123", "2018-11-02", "0", "0", "0"],
      ["DEF456", "2018-11-01", "1", "1", "1"],
      ["DEF456", "2018-11-02", "0", "0", "0"],
      [],
      ratios_column_header(false),
      ["ABC123", "1", "1", "1", "1", "1.0", "1.0"],
      ["DEF456", "1", "1", "1", "1", "1.0", "1.0"],
    ]

    assert_equal expected, CSV.parse(csv)
  end

  test "generates report for running total with geo information" do
    Rails.application.secrets[:api_promo_base_uri] = "http://127.0.0.1:8194/"
    PromoRegistration.create!(referral_code: "ABC123", kind: "unattached", promo_id: "free-bats-2018q1")
    PromoRegistration.create!(referral_code: "DEF456", kind: "unattached", promo_id: "free-bats-2018q1")

    stub_request(:get, /geoStatsByReferralCode/).
      to_return(body: GEO_STATS.to_json)

    csv = Promo::RegistrationStatsReportGenerator.new(referral_codes: ["ABC123", "DEF456"],
                                                      start_date: "2018-11-01".to_date,
                                                      end_date: "2018-12-01".to_date,
                                                      reporting_interval: PromoRegistration::RUNNING_TOTAL,
                                                      is_geo: true).perform

    expected = [
      [
        "Referral code",
        "Country", reporting_interval_column_header(PromoRegistration::RUNNING_TOTAL),
        event_type_column_header(PromoRegistration::RETRIEVALS),
        event_type_column_header(PromoRegistration::FIRST_RUNS),
        event_type_column_header(PromoRegistration::FINALIZED),
      ],
      ["ABC123", "Mexico", "2018-12-01", "6", "6", "6"],
      ["ABC123", "United States", "2018-12-01", "6", "6", "6"],
      ["DEF456", "Mexico", "2018-12-01", "6", "6", "6"],
      ["DEF456", "United States", "2018-12-01", "6", "6", "6"],
      [],
      ratios_column_header(true),
      ["ABC123", "Mexico", "6", "6", "6", "6", "1.0", "1.0"],
      ["ABC123", "United States", "6", "6", "6", "6", "1.0", "1.0"],
      ["DEF456", "Mexico", "6", "6", "6", "6", "1.0", "1.0"],
      ["DEF456", "United States", "6", "6", "6", "6", "1.0", "1.0"],
    ]

    assert_equal expected, CSV.parse(csv)
  end

  test "generates report for weekly with geo information" do
    Rails.application.secrets[:api_promo_base_uri] = "http://127.0.0.1:8194/"
    PromoRegistration.create!(referral_code: "ABC123", kind: "unattached", promo_id: "free-bats-2018q1")
    PromoRegistration.create!(referral_code: "DEF456", kind: "unattached", promo_id: "free-bats-2018q1")

    stub_request(:get, /geoStatsByReferralCode/).
      to_return(body: GEO_STATS.to_json)

    csv = Promo::RegistrationStatsReportGenerator.new(referral_codes: ["ABC123", "DEF456"],
                                                      start_date: "2018-11-01".to_date,
                                                      end_date: "2018-11-14".to_date,
                                                      reporting_interval: PromoRegistration::WEEKLY,
                                                      is_geo: true).perform

    expected = [
      [
        "Referral code",
        "Country", reporting_interval_column_header(PromoRegistration::WEEKLY),
        event_type_column_header(PromoRegistration::RETRIEVALS),
        event_type_column_header(PromoRegistration::FIRST_RUNS),
        event_type_column_header(PromoRegistration::FINALIZED),
      ],
      ["ABC123", "Mexico", "2018-10-29", "1", "1", "1"],
      ["ABC123", "Mexico", "2018-11-05", "1", "1", "1"],
      ["ABC123", "Mexico", "2018-11-12", "1", "1", "1"],
      ["ABC123", "United States", "2018-10-29", "1", "1", "1"],
      ["ABC123", "United States", "2018-11-05", "1", "1", "1"],
      ["ABC123", "United States", "2018-11-12", "1", "1", "1"],
      ["DEF456", "Mexico", "2018-10-29", "1", "1", "1"],
      ["DEF456", "Mexico", "2018-11-05", "1", "1", "1"],
      ["DEF456", "Mexico", "2018-11-12", "1", "1", "1"],
      ["DEF456", "United States", "2018-10-29", "1", "1", "1"],
      ["DEF456", "United States", "2018-11-05", "1", "1", "1"],
      ["DEF456", "United States", "2018-11-12", "1", "1", "1"],
      [],
      ratios_column_header(true),
      ["ABC123", "Mexico", "3", "3", "3", "3", "1.0", "1.0"],
      ["ABC123", "United States", "3", "3", "3", "3", "1.0", "1.0"],
      ["DEF456", "Mexico", "3", "3", "3", "3", "1.0", "1.0"],
      ["DEF456", "United States", "3", "3", "3", "3", "1.0", "1.0"],
    ]

    assert_equal expected, CSV.parse(csv)
  end
end
