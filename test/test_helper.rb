ENV["RAILS_ENV"] ||= "test"
require File.expand_path("../../config/environment", __FILE__)
require "rails/test_help"
require "selenium/webdriver"
require "minitest/rails/capybara"
require "webmock/minitest"
require "chromedriver/helper"
require 'sidekiq/testing'
require 'mail_chimp/api'

Sidekiq::Testing.fake!

WebMock.allow_net_connect!

Chromedriver.set_version "2.35"

Capybara.register_driver :chrome do |app|
  capabilities = Selenium::WebDriver::Remote::Capabilities.chrome(
    chromeOptions: { args: %w(headless disable-gpu window-size=1680,1050) }
  )

  Capybara::Selenium::Driver.new app,
    browser: :chrome,
    desired_capabilities: capabilities
end

VCR.configure do |config|
  config.cassette_library_dir = "./test/cassettes"
  config.hook_into :webmock
  config.filter_sensitive_data("<ENCODED API KEY>") {
    Base64.encode64(["apikey", Rails.application.secrets[:mailchimp_api_key]].join(':')).chomp
  }
  config.ignore_hosts '127.0.0.1', 'localhost'
end

class Capybara::Rails::TestCase
  def setup
    Capybara.current_driver = :chrome
  end
end

module ActiveSupport
  class TestCase
    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all
    self.use_transactional_tests = true

    # Add more helper methods to be used by all tests here...
  end
end

module Capybara
  module Rails
    class TestCase < ::ActiveSupport::TestCase
      self.use_transactional_tests = false

      setup do
        DatabaseCleaner.start
      end

      teardown do
        DatabaseCleaner.clean
      end

    end
  end
end

module ActionDispatch
  class IntegrationTest
    self.use_transactional_tests = true

    setup do
      WebMock.disable_net_connect!
    end

    teardown do
      WebMock.allow_net_connect!
    end

    def visit_authentication_url(publisher)
      get publisher_url(publisher, token: publisher.authentication_token)
    end
  end
end

# One time test suite setup.
DatabaseCleaner.strategy = :transaction
DatabaseCleaner.clean_with(:truncation)

require 'mocha/mini_test'
