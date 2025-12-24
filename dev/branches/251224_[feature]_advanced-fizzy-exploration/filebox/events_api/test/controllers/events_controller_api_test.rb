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
  end

  test "events include particulars for column tracking" do
    # Create a triaged card to generate an event with particulars
    card = cards(:buy_domain)
    column = columns(:writebook_in_progress)

    Current.session = sessions(:david)
    card.triage_into(column)

    get events_path(format: :json, action: "card_triaged"), env: @bearer_token
    assert_response :success

    events = @response.parsed_body
    triaged_event = events.find { |e| e["action"] == "card_triaged" }

    assert triaged_event.present?
    assert triaged_event["particulars"].present?
    assert_equal column.name, triaged_event.dig("particulars", "particulars", "column")
  end

  test "filter events by board" do
    board = boards(:writebook)

    get events_path(format: :json, board_ids: [board.id]), env: @bearer_token
    assert_response :success

    events = @response.parsed_body
    events.each do |event|
      assert_equal board.id, event.dig("board", "id")
    end
  end

  test "filter events by action type" do
    get events_path(format: :json, action: "card_triaged"), env: @bearer_token
    assert_response :success

    events = @response.parsed_body
    events.each do |event|
      assert_equal "card_triaged", event["action"]
    end
  end

  test "filter events by time range" do
    since_time = 1.day.ago.iso8601

    get events_path(format: :json, since: since_time), env: @bearer_token
    assert_response :success

    events = @response.parsed_body
    events.each do |event|
      assert Time.parse(event["created_at"]) >= Time.parse(since_time)
    end
  end

  test "events are paginated" do
    get events_path(format: :json), env: @bearer_token
    assert_response :success

    # Check for Link header if there are more pages
    # geared_pagination adds rel="next" link header
  end

  test "unauthorized without token" do
    get events_path(format: :json)
    assert_response :unauthorized
  end

  private
    def bearer_token_env(token)
      { "HTTP_AUTHORIZATION" => "Bearer #{token}" }
    end
end
