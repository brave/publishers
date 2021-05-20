require "test_helper"
require "webmock/minitest"

class SiteChannelDomainSetterTest < ActiveJob::TestCase
  def setup
    @prev_host_inspector_offline = Rails.application.secrets[:host_inspector_offline]
    @prev_api_eyeshade_offline = Rails.application.secrets[:api_eyeshade_offline]

    Rails.application.secrets[:host_inspector_offline] = false
    Rails.application.secrets[:api_eyeshade_offline] = false
  end

  def teardown
    Rails.application.secrets[:host_inspector_offline] = @prev_host_inspector_offline
    Rails.application.secrets[:api_eyeshade_offline] = @prev_api_eyeshade_offline
  end

  test "normalizes and inspects the domain" do
    mock_response = {
      "protocol": "http:",
      "slashes": true,
      "auth": null,
      "host": "example.com",
      "port": null,
      "hostname": "foo-bar.com",
      "hash": null,
      "search": "",
      "query": {
      },
      "pathname": "/",
      "path": "/",
      "href": "http://foo-bar.com/",
      "TLD": "com",
      "URL": "http://foo-bar.com",
      "SLD": "foo-bar.com",
      "RLD": "",
      "QLD": "",
      "publisher": "example.com",
    }
    stub_request(:get, /v1\/publishers\/identity\?url=https:\/\/example\.com/).
      to_return(status: 200, body: mock_response.to_json, headers: {})

    stub_request(:get, "https://example.com").
      to_return(status: 200, body: "<html><body><h1>Welcome to mysite</h1></body></html>", headers: {})

    channel_details = SiteChannelDetails.new
    channel_details.brave_publisher_id_unnormalized = "https://example.com"

    SiteChannelDomainSetter.new(channel_details: channel_details).perform

    assert_equal 'example.com', channel_details.brave_publisher_id
    assert channel_details.supports_https
    assert_nil channel_details.detected_web_host
    assert channel_details.host_connection_verified
  end

  test "normalizes domain for http" do
    ["https://http-lib.com", "http://http-lib.com", "http-lib.com", "www.http-lib.com", "http://http-lib.com", "http://http-lib.com/index.html"].each do |unnormalized_url|
      channel_details = SiteChannelDetails.new
      channel_details.brave_publisher_id_unnormalized = unnormalized_url
      SiteChannelDomainSetter.new(channel_details: channel_details).perform
      assert_equal 'http-lib.com', channel_details.brave_publisher_id
    end
  end

  test "captures popular subdomains" do
    channel_details = SiteChannelDetails.new
    channel_details.brave_publisher_id_unnormalized = "https://yachtcaptain23.github.io"
    SiteChannelDomainSetter.new(channel_details: channel_details).perform
    assert_equal 'yachtcaptain23.github.io', channel_details.brave_publisher_id

    channel_details = SiteChannelDetails.new
    channel_details.brave_publisher_id_unnormalized = "http://helloworld.blogspot.com"
    SiteChannelDomainSetter.new(channel_details: channel_details).perform
    assert_equal 'helloworld.blogspot.com', channel_details.brave_publisher_id

    ["https://yachtcaptain23.keybase.pub", "http://yachtcaptain23.keybase.pub"].each do |unnormalized_url|
      channel_details = SiteChannelDetails.new
      channel_details.brave_publisher_id_unnormalized = unnormalized_url
      SiteChannelDomainSetter.new(channel_details: channel_details).perform
      assert_equal 'yachtcaptain23.keybase.pub', channel_details.brave_publisher_id
    end

    # Franchise Tax Board
    channel_details = SiteChannelDetails.new
    channel_details.brave_publisher_id_unnormalized = "https://www.ftb.ca.gov/professionals/efile/forms/irsForms/irsTOC.shtml"
    SiteChannelDomainSetter.new(channel_details: channel_details).perform
    assert_equal 'ca.gov', channel_details.brave_publisher_id
  end

  test "skips normalization if it's unnecessary and just inspects the domain" do
    stub_request(:get, "https://example.com").
      to_return(status: 200, body: "<html><body><h1>Welcome to mysite</h1></body></html>", headers: {})

    channel_details = SiteChannelDetails.new
    channel_details.brave_publisher_id = "example.com"

    refute channel_details.supports_https
    assert_nil channel_details.detected_web_host
    refute channel_details.host_connection_verified

    SiteChannelDomainSetter.new(channel_details: channel_details).perform

    assert channel_details.supports_https
    assert_nil channel_details.detected_web_host
    assert channel_details.host_connection_verified
  end

  test "normalization can succeed and inspection can fail if connection to site fails when https and http fail" do
    mocked_response = {
      "protocol": "http:",
      "slashes": true,
      "auth": null,
      "host": "mywordpressisdown.com",
      "port": null,
      "hostname": "foo-bar.com",
      "hash": null,
      "search": "",
      "query": {
      },
      "pathname": "/",
      "path": "/",
      "href": "http://foo-bar.com/",
      "TLD": "com",
      "URL": "http://foo-bar.com",
      "SLD": "foo-bar.com",
      "RLD": "",
      "QLD": "",
      "publisher": "mywordpressisdown.com",
    }
    stub_request(:get, /v1\/publishers\/identity\?url=https:\/\/mywordpressisdown\.com/).
      with(headers: { 'Accept' => '*/*', 'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'User-Agent' => 'Faraday v0.9.2' }).
      to_return(status: 200, body: mocked_response.to_json, headers: {})

    stub_request(:get, "https://mywordpressisdown.com").
      to_raise(Errno::ECONNREFUSED.new)
    stub_request(:get, "https://www.mywordpressisdown.com").
      to_raise(Errno::ECONNREFUSED.new)

    stub_request(:get, "http://mywordpressisdown.com").
      to_raise(Errno::ECONNREFUSED.new)

    channel_details = SiteChannelDetails.new
    channel_details.brave_publisher_id_unnormalized = "mywordpressisdown.com"

    SiteChannelDomainSetter.new(channel_details: channel_details).perform

    refute channel_details.supports_https
    assert_nil channel_details.detected_web_host
    refute channel_details.host_connection_verified
  end

  test "Catches an error code of an invalid url with a protocol" do
    channel_details = SiteChannelDetails.new
    channel_details.brave_publisher_id_unnormalized = "https://bad url.com"
    SiteChannelDomainSetter.new(channel_details: channel_details).perform
    assert_equal 'invalid_uri', channel_details.brave_publisher_id_error_code
  end

  test "Catches an error code of an invalid url without a protocol" do
    channel_details = SiteChannelDetails.new
    channel_details.brave_publisher_id_unnormalized = "bad url.com"
    SiteChannelDomainSetter.new(channel_details: channel_details).perform
    assert_equal 'invalid_uri', channel_details.brave_publisher_id_error_code
  end

  test "does not raise an exception when domain is already taken by a verified publisher" do
    mocked_response = {
      "protocol": "http:",
      "slashes": true,
      "auth": null,
      "host": "verified.org",
      "port": null,
      "hostname": "foo-bar.com",
      "hash": null,
      "search": "",
      "query": {
      },
      "pathname": "/",
      "path": "/",
      "href": "http://foo-bar.com/",
      "TLD": "com",
      "URL": "http://foo-bar.com",
      "SLD": "foo-bar.com",
      "RLD": "",
      "QLD": "",
      "publisher": "verified.org",
    }
    stub_request(:get, /v1\/publishers\/identity\?url=https:\/\/verified\.org/).
      with(headers: { 'Accept' => '*/*', 'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'User-Agent' => 'Faraday v0.9.2' }).
      to_return(status: 200, body: mocked_response.to_json, headers: {})

    channel_details = SiteChannelDetails.new

    existing_channel = channels(:verified)
    channel_details.brave_publisher_id_unnormalized = existing_channel.details.brave_publisher_id
    SiteChannelDomainSetter.new(channel_details: channel_details).perform

    assert_nil channel_details.brave_publisher_id_error_code
  end
end
