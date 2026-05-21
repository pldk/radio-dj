require "test_helper"

class MessagesControllerTest < ActionDispatch::IntegrationTest
  test "GET / returns dashboard" do
    get root_url
    assert_response :success
  end

  test "POST /messages with valid params creates message" do
    audio_path = Rails.root.join("test/fixtures/files/test.wav").to_s
    assert_difference("Message.count", 1) do
      post messages_url, params: { listener_name: "Jonas", audio: audio_path }
    end
    assert_response :created
  end

  test "POST /messages without params returns 422" do
    post messages_url, params: {}
    assert_response :unprocessable_entity
  end

  test "POST /messages with missing file returns 422" do
    post messages_url, params: { listener_name: "Jonas", audio: "/tmp/nonexistent.wav" }
    assert_response :unprocessable_entity
  end
end
