require "test_helper"

class Cards::ReadingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "read one notification on card visit" do
    assert_changes -> { notifications(:logo_published_kevin).reload.read? }, from: false, to: true do
      post card_reading_path(cards(:logo)), as: :turbo_stream
    end

    assert_response :success
  end

  test "read multiple notifications on card visit" do
    assert_changes -> { notifications(:logo_published_kevin).reload.read? }, from: false, to: true do
      assert_changes -> { notifications(:logo_assignment_kevin).reload.read? }, from: false, to: true do
        post card_reading_path(cards(:logo)), as: :turbo_stream
      end
    end

    assert_response :success
  end

  test "create opts-out of writer affinity in the load balancer" do
    post card_reading_path(cards(:logo)), as: :turbo_stream

    assert_equal "false", response.headers["X-Writer-Affinity"]
  end
end
