require "test_helper"

class Promo::RegistrationInstallerTypeSetterTest < ActiveJob::TestCase
  include PromosHelper

  before(:example) do
    @prev_promo_api_uri = Rails.application.secrets[:api_promo_base_uri]
  end

  after(:example) do
    Rails.application.secrets[:api_promo_base_uri] = @prev_promo_api_uri
  end

  test "does not update installer type if promo server response is not 200" do
    Rails.application.secrets[:api_promo_base_uri] = "http://127.0.0.1:8194"

    PromoRegistration.create(promo_id: active_promo_id,
                             referral_code: "XYZ999",
                             kind: PromoRegistration::UNATTACHED)

    PromoRegistration.create(promo_id: active_promo_id,
                             referral_code: "XYZ000",
                             kind: PromoRegistration::UNATTACHED)

    stub_request(:put, "#{Rails.application.secrets[:api_promo_base_uri]}/api/2/promo/referral/installerType").
      to_return(status: 200)

    Promo::RegistrationInstallerTypeSetter.new(promo_registrations: PromoRegistration.unattached_only,
                                               installer_type: PromoRegistration::MOBILE).perform

    PromoRegistration.unattached_only.each do |promo_registration|
      assert promo_registration.installer_type == PromoRegistration::MOBILE
    end
  end
end
