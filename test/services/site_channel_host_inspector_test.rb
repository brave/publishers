require "test_helper"
require "webmock/minitest"

class SiteChannelHostInspectorTest < ActiveJob::TestCase
  def setup
    Rails.application.secrets[:host_inspector_offline] = false
  end

  def teardown
    Rails.application.secrets[:host_inspector_offline] = true
  end

  test "inspects the domain for github" do
    stub_request(:get, "https://mysite.github.io").
      to_return(status: 200, body: "<html><body><h1>Welcome to mysite</h1></body></html>", headers: {})

    result = SiteChannelHostInspector.new(url: "mysite.github.io").perform
    assert result[:host_connection_verified]
    assert_equal 'github', result[:web_host]
    assert result[:https]
  end

  test "inspects the response for github with custom name" do
    stub_request(:get, "https://mysite.com").
      to_return(status: 200, body: "<html><body><h1>Welcome to mysite</h1></body></html>", headers: {})

    result = SiteChannelHostInspector.new(url: "mysite.com").perform
    assert result[:https]
    assert result[:host_connection_verified]
    # ToDo: detect github pages sites with custom name
    assert_nil result[:web_host]
  end

  test "sets https_error when there is an OpenSSL::SSL::SSLError exception" do
    stub_request(:get, "https://expired.badssl.com").
      to_raise(OpenSSL::SSL::SSLError.new('SSL_connect returned=1 errno=0 state=error: certificate verify failed'))
    stub_request(:get, "https://www.expired.badssl.com").
      to_raise(OpenSSL::SSL::SSLError.new('SSL_connect returned=1 errno=0 state=error: certificate verify failed'))

    result = SiteChannelHostInspector.new(url: "expired.badssl.com", require_https: true).perform

    refute result[:host_connection_verified]
    refute result[:https]
    assert_equal result[:https_error], 'SSL_connect returned=1 errno=0 state=error: certificate verify failed'
    assert_nil result[:web_host]
  end

  test "returns a nil web_host if site does not support a known method" do
    stub_request(:get, "https://mystandardsite.com").
      to_return(status: 200, body: "<html><body><h1>Welcome to mysite hosted with apache</h1></body></html>", headers: {})

    result = SiteChannelHostInspector.new(url: "mystandardsite.com").perform
    assert result[:host_connection_verified]
    assert result[:https]
    assert_nil result[:web_host]
  end

  test "inspects the domain for wordpress" do
    stub_request(:get, "https://mywordpress.com").
      to_return(status: 200, body: "<html><body><h1>Welcome to mysite made with /wp-content/</h1></body></html>", headers: {})

    result = SiteChannelHostInspector.new(url: "mywordpress.com").perform
    assert result[:host_connection_verified]
    assert result[:https]
    assert_equal 'wordpress', result[:web_host]
  end

  test "inspects www subdomain when root domain fails" do
    stub_request(:get, "https://wwwonly.com").
      to_raise(Errno::ECONNREFUSED.new)
    stub_request(:get, "https://www.wwwonly.com").
      to_return(status: 200, body: "<html><body><h1>Welcome to mysite</h1></body></html>", headers: {})

    result = SiteChannelHostInspector.new(url: "wwwonly.com").perform
    assert result[:host_connection_verified]
    assert result[:https]
  end

  test "https is false if site fails https and http succeeds" do
    stub_request(:get, "https://banhttps.com").
      to_raise(Errno::ECONNREFUSED.new)
    stub_request(:get, "https://www.banhttps.com").
      to_raise(Errno::ECONNREFUSED.new)

    stub_request(:get, "http://banhttps.com").
      to_return(status: 200, body: "<html><body><h1>Welcome to mysite made with /wp-content/</h1></body></html>", headers: {})

    result = SiteChannelHostInspector.new(url: "banhttps.com").perform
    assert result[:host_connection_verified]
    refute result[:https]
    assert_equal 'wordpress', result[:web_host]
  end

  test "connection to site fails when https and http fail" do
    stub_request(:get, "https://mywordpressisdown.com").
      to_raise(Errno::ECONNREFUSED.new)
    stub_request(:get, "https://www.mywordpressisdown.com").
      to_raise(Errno::ECONNREFUSED.new)

    stub_request(:get, "http://mywordpressisdown.com").
      to_raise(Errno::ECONNREFUSED.new)

    result = SiteChannelHostInspector.new(url: "mywordpressisdown.com").perform
    refute result[:host_connection_verified]
    refute result[:https]
    assert_nil result[:web_host]
    assert result[:response].is_a?(Errno::ECONNREFUSED)
  end

  test "connection to site fails when https fails and http is require_https is true" do
    stub_request(:get, "https://mywordpressisdown.com").
      to_raise(Errno::ECONNREFUSED.new)
    stub_request(:get, "https://www.mywordpressisdown.com").
      to_raise(Errno::ECONNREFUSED.new)

    result = SiteChannelHostInspector.new(url: "mywordpressisdown.com", require_https: true).perform
    refute result[:host_connection_verified]
    refute result[:https]
    assert_nil result[:web_host]
    assert result[:response].is_a?(Errno::ECONNREFUSED)
  end

  test "follows local redirects" do
    stub_request(:get, "https://mywordpress.com").
      to_return(status: 301, headers: { location: "index.html" })

    stub_request(:get, "https://mywordpress.com/index.html").
      to_return(status: 200, body: "<html><body><h1>Welcome to mysite made with /wp-content/</h1></body></html>", headers: {})

    result = SiteChannelHostInspector.new(url: "mywordpress.com").perform
    assert result[:host_connection_verified]
    assert result[:https]
    assert_equal 'wordpress', result[:web_host]
  end

  test "follows local redirects with added host name" do
    stub_request(:get, "https://mywordpress.com").
      to_return(status: 301, headers: { location: "https://www.mywordpress.com/" })

    stub_request(:get, "https://www.mywordpress.com/").
      to_return(status: 200, body: "<html><body><h1>Welcome to mysite made with /wp-content/</h1></body></html>", headers: {})

    result = SiteChannelHostInspector.new(url: "mywordpress.com").perform
    assert result[:host_connection_verified]
    assert result[:https]
    assert_equal 'wordpress', result[:web_host]
  end

  test "does not follow all redirects if follow_all_redirects is not enabled" do
    stub_request(:get, "https://mywordpress.com").
      to_return(status: 301, headers: { location: "https://mywordpress2.com/index.html" })
    stub_request(:get, "https://www.mywordpress.com").
      to_return(status: 301, headers: { location: "https://mywordpress2.com/index.html" })

    stub_request(:get, "https://mywordpress2.com/index.html").
      to_return(status: 200, body: "<html><body><h1>Welcome to mysite made with /wp-content/</h1></body></html>", headers: {})

    result = SiteChannelHostInspector.new(url: "mywordpress.com", require_https: true).perform
    refute result[:host_connection_verified]
    refute result[:https]
    assert_nil result[:web_host]
    assert result[:response].is_a?(Publishers::Fetch::RedirectError)
    assert_equal "non local redirects prohibited", result[:response].to_s
  end

  test "follows all redirects if follow_all_redirects is enabled" do
    stub_request(:get, "https://mywordpress.com").
      to_return(status: 301, headers: { location: "https://mywordpress2.com/index.html" })

    stub_request(:get, "https://mywordpress2.com/index.html").
      to_return(status: 200, body: "<html><body><h1>Welcome to mysite made with /wp-content/</h1></body></html>", headers: {})

    result = SiteChannelHostInspector.new(url: "mywordpress.com", follow_all_redirects: true).perform
    assert result[:host_connection_verified]
    assert result[:https]
    assert_equal 'wordpress', result[:web_host]
  end
end
