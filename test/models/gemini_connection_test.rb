require "test_helper"
require "shared/mailer_test_helper"
require "webmock/minitest"

class GeminiConnectionTest < ActiveSupport::TestCase
  include MockGeminiResponses

  describe 'validations' do
    let(:gemini_connection) { gemini_connections(:default_connection) }

    describe 'when recipient_id is nil' do
      before do
        gemini_connection.recipient_id = nil
      end

      it 'is valid' do
        assert gemini_connection.valid?
      end
    end
  end

  describe 'after destroy hook' do
    let(:gemini_connection) { gemini_connections(:connection_with_token) }
    let(:publisher) { publishers(:gemini_completed) }
    test 'publisher no longer has a selected wallet provider' do
      assert_equal publisher.selected_wallet_provider, gemini_connection
      gemini_connection.destroy
      publisher.reload
      assert_nil publisher.selected_wallet_provider
    end
  end

  describe 'refresh_authorization! retrieves a new token' do
    let(:gemini_connection) { gemini_connections(:connection_with_token) }
    subject { gemini_connection.refresh_authorization! }

    before do
      mock_gemini_auth_request!
      mock_gemini_account_request!
      mock_gemini_recipient_id!
    end

    it 'refreshes the token' do
      assert_equal gemini_connection.access_token, 'access_token'
      subject
      assert_equal gemini_connection.access_token, 'km2bylijaDkceTOi2LiranELqdQqvsjFuHcSuQ5aU9jm'
    end
  end

  describe '#sync_connection' do
    let(:subject) { connection.sync_connection! }

    describe 'when a connection is not payable' do
      let(:connection) { gemini_connections(:connection_not_verified_no_address) }
      before do
        mock_gemini_unverified_account_request!
      end

      it 'does not create a recipient id' do
        refute connection.recipient_id
        subject
        refute connection.recipient_id
      end

      it 'updates other properties' do
        refute connection.display_name
        subject
        assert connection.display_name
      end
    end

    describe 'when a connection is payable' do
      let(:connection) { gemini_connections(:connection_with_token) }

      before do
        mock_gemini_account_request!
        mock_gemini_recipient_id!
      end

      it 'does creates a recipient id' do
        connection.update(recipient_id: nil)
        refute connection.recipient_id
        subject
        assert connection.recipient_id
      end
    end
  end
end
