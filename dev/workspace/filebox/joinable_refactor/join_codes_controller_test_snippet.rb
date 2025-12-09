# Add this test to test/controllers/join_codes_controller_test.rb
#
# Tests the reactivation flow through the join code UI.
# When a deactivated user's identity uses a join code to rejoin,
# they should be reactivated and redirected to landing (if setup).

test "create for existing identity with deactivated user" do
  identity = identities(:kevin)
  user = users(:kevin)

  sign_in_as :kevin

  assert user.setup?, "Kevin should be setup for this test"
  user.deactivate

  assert_not user.reload.active?, "user should be inactive after deactivation"
  assert_equal identity.id, user.identity_id, "identity link should be preserved after deactivation"

  assert_no_difference -> { User.count } do
    post join_path(code: @join_code.code, script_name: @account.slug), params: { email_address: identity.email_address }
  end

  user.reload
  assert user.active?, "user should be reactivated after joining"
  assert_redirected_to landing_url(script_name: @account.slug)
end
