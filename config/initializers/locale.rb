I18n.load_path += Dir["#{Rails.root}/config/locales/**/*.yml"]
I18n.default_locale = :en
I18n.available_locales = [:en, :ja]
