# Add this test to test/models/identity/joinable_test.rb
#
# Tests the reactivation feature added to Identity::Joinable#join.
# When a deactivated user's identity rejoins the same account, the existing
# user record should be found, reactivated, and have board accesses restored.

test "join reactivates a deactivated user" do
  identity = identities(:kevin)
  account = accounts("37s")
  user = users(:kevin)

  user.stubs(:close_remote_connections)
  user.deactivate

  assert_not user.reload.active?, "user should be inactive after deactivation"
  assert_empty user.accesses, "user should have no accesses after deactivation"
  assert_equal identity.id, user.identity_id, "identity link should be preserved after deactivation"

  assert_no_difference -> { User.count } do
    result = identity.join(account)
    assert_not result, "join should return false for reactivation"
  end

  user.reload
  assert user.active?, "user should be active after reactivation"
  assert user.accesses.any?, "user should have accesses restored after reactivation"
end
