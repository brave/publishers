require "test_helper"

class Api::V1::Public::PublishersControllerTest < ActionDispatch::IntegrationTest
  test "totals endpoint works" do
    # (Albert Wang): TODO, move this to private API
    return
    get api_v1_public_publishers_totals_path
    assert JSON.parse(response.body)
    assert_response 200
  end
end
