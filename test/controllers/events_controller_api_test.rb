require "test_helper"

class EventsControllerApiTest < ActionDispatch::IntegrationTest
  setup do
    @bearer_token = bearer_token_env(identity_access_tokens(:davids_api_token).token)
  end

  test "get events list" do
    get events_path(format: :json), env: @bearer_token
    assert_response :success

    events = @response.parsed_body
    assert events.is_a?(Array)
    assert events.any?
  end

  test "events include required fields" do
    get events_path(format: :json), env: @bearer_token
    assert_response :success

    event = @response.parsed_body.first
    assert event["id"].present?
    assert event["action"].present?
    assert event["created_at"].present?
    assert event["board"].present?
    assert event["creator"].present?
    assert event["eventable_type"].present?
  end

  test "events include particulars" do
    get events_path(format: :json, event_action: "card_assigned"), env: @bearer_token
    assert_response :success

    events = @response.parsed_body
    assigned_event = events.find { |e| e["action"] == "card_assigned" }

    assert assigned_event.present?
    assert assigned_event["particulars"].present?
  end

  test "filter events by board" do
    board = boards(:writebook)

    get events_path(format: :json, board_ids: [board.id]), env: @bearer_token
    assert_response :success

    events = @response.parsed_body
    assert events.any?
    events.each do |event|
      assert_equal board.id, event.dig("board", "id")
    end
  end

  test "filter events by action type" do
    get events_path(format: :json, event_action: "card_published"), env: @bearer_token
    assert_response :success

    events = @response.parsed_body
    assert events.any?
    events.each do |event|
      assert_equal "card_published", event["action"]
    end
  end

  test "filter events by multiple actions" do
    get events_path(format: :json, event_actions: ["card_published", "card_assigned"]), env: @bearer_token
    assert_response :success

    events = @response.parsed_body
    assert events.any?
    events.each do |event|
      assert_includes ["card_published", "card_assigned"], event["action"]
    end
  end

  test "filter events by time range" do
    since_time = 3.days.ago.iso8601

    get events_path(format: :json, since: since_time), env: @bearer_token
    assert_response :success

    events = @response.parsed_body
    events.each do |event|
      assert Time.parse(event["created_at"]) >= Time.parse(since_time)
    end
  end

  test "card events include card data" do
    get events_path(format: :json, event_action: "card_published"), env: @bearer_token
    assert_response :success

    events = @response.parsed_body
    card_event = events.find { |e| e["eventable_type"] == "Card" }

    assert card_event.present?
    assert card_event["card"].present?
    assert card_event.dig("card", "id").present?
    assert card_event.dig("card", "title").present?
  end

  test "comment events include comment and card data" do
    get events_path(format: :json, event_action: "comment_created"), env: @bearer_token
    assert_response :success

    events = @response.parsed_body
    comment_event = events.find { |e| e["eventable_type"] == "Comment" }

    if comment_event.present?
      assert comment_event["comment"].present?
      assert comment_event["card"].present?
    end
  end

  test "unauthorized with invalid token" do
    get events_path(format: :json), env: bearer_token_env("invalid_token")
    assert_response :unauthorized
  end

  test "events are ordered by created_at descending" do
    get events_path(format: :json), env: @bearer_token
    assert_response :success

    events = @response.parsed_body
    if events.length > 1
      timestamps = events.map { |e| Time.parse(e["created_at"]) }
      assert_equal timestamps, timestamps.sort.reverse, "Events should be ordered by created_at desc"
    end
  end

  private
    def bearer_token_env(token)
      { "HTTP_AUTHORIZATION" => "Bearer #{token}" }
    end
end
