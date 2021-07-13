class AddRekeyedFieldToEncryptedFields < ActiveRecord::Migration[6.1]
  def change
    add_column :bitflyer_connections, :access_token_rekeyed, :boolean, default: false
    add_column :bitflyer_connections, :refresh_token_rekeyed, :boolean, default: false
    add_column :gemini_connections, :access_token_rekeyed, :boolean, default: false
    add_column :gemini_connections, :refresh_token_rekeyed, :boolean, default: false
    add_column :paypal_connections, :refresh_token_rekeyed, :boolean, default: false
    add_column :stripe_connections, :access_token_rekeyed, :boolean, default: false
    add_column :stripe_connections, :refresh_token_rekeyed, :boolean, default: false
    add_column :uphold_connections, :uphold_code_rekeyed, :boolean, default: false
    add_column :uphold_connections, :uphold_access_parameters_rekeyed, :boolean, default: false
    add_column :payout_reports, :contents_rekeyed, :boolean, default: false
    add_column :user_authentication_tokens, :authentication_token_rekeyed, :boolean, default: false
    add_column :totp_registrations, :secret_rekeyed, :boolean, default: false
  end
end
