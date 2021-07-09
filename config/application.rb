require_relative "boot"

require "rails/all"

# Have to require this middleware
# https://github.com/rails/rails/issues/25525
require_relative 'middlewares/http_header_middleware'

# Require the gems listed in Gemfile, including any gems
# you"ve limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Publishers
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.
    config.load_defaults 6.1
    config.middleware.use HttpHeaderMiddleware
    config.middleware.use Rack::Deflater

    config.active_job.queue_adapter = :sidekiq

    config.autoload_paths += %W(#{config.root}/app/services/ #{config.root}/lib #{config.root}/app/validators/ #{config.root}/lib/devise #{config.root}/protos #{config.root}/app/models/stats_redshift)

    config.exceptions_app = routes

    if Rails.application.secrets[:log_verbose].present?
      config.log_level = :debug
    else
      config.log_level = :info
    end

    config.action_mailer.delivery_job = "ActionMailer::MailDeliveryJob"
    config.active_record.belongs_to_required_by_default = false

    config.time_zone = "Pacific Time (US & Canada)"
    config.active_record.default_timezone = :local

    config.active_storage.queues.analysis = :low
    config.active_storage.queues.purge    = :low
    config.ssl_options = { redirect: { exclude: -> request { request.path =~ /health-check/ } } }

    # config.i18n.load_path += Dir[Rails.root.join('config', 'locales', '**', '*.{rb,yml}')]
    #    config.i18n.load_path += Dir["#{Rails.root.to_s}/config/locales/**/*.{rb,yml}"]
    #    config.i18n.default_locale = :en

    config.services = config_for(:services)

    # Let's ensure that our generators make a UUID as default
    config.generators do |generator|
      generator.orm :active_record, primary_key_type: :uuid
    end
  end
end
