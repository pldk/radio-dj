require "test_helper"

class MessagesControllerTest < ActionDispatch::IntegrationTest
  test "should get dashboard" do
    get messages_dashboard_url
    assert_response :success
  end

  test "should get stream" do
    get messages_stream_url
    assert_response :success
  end

  test "should get create" do
    get messages_create_url
    assert_response :success
  end
end
