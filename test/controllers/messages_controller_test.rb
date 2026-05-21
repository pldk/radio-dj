require "test_helper"

class MessagesControllerTest < ActionDispatch::IntegrationTest
  test "GET / returns dashboard" do
    get root_url
    assert_response :success
  end

  test "POST /messages with valid params creates message" do
    fixture = fixture_file_upload("test.wav", "audio/wav")
    assert_difference("Message.count", 1) do
      post messages_url, params: { listener_name: "Jonas", audio: fixture }
    end
    assert_response :created
    assert_equal "pending", Message.last.status
  end

  test "POST /messages without params returns 422" do
    post messages_url, params: {}
    assert_response :unprocessable_entity
  end

  test "POST /messages without audio returns 422" do
    post messages_url, params: { listener_name: "Jonas" }
    assert_response :unprocessable_entity
  end

  test "POST /messages enqueues a TranscribeJob" do
    fixture = fixture_file_upload("test.wav", "audio/wav")
    assert_enqueued_with(job: TranscribeJob) do
      post messages_url, params: { listener_name: "Jonas", audio: fixture }
    end
  end
end
