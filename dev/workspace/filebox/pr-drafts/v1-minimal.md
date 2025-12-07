# PR Draft v1 - Minimal (Bug Fix Only)

**Title:** Fix Identity#destroy callback ordering for user deactivation

## Summary

Fixes a bug where `Identity#destroy` fails to properly deactivate users due to callback ordering.

## The Bug

When an Identity is destroyed, the `deactivate_users` callback runs **after** `dependent: :nullify` because Rails adds association callbacks in declaration order. By the time `deactivate_users` iterates over `users.find_each`, the association is already empty (`identity_id` has been set to NULL).

**Result:** Users are orphaned with `active: true`, accesses intact, but `identity_id: nil`.

### Reproduction

```ruby
identity = Identity.create!(email_address: "test@example.com")
identity.join(account)
user = identity.users.first

identity.destroy!
user.reload

user.active        # => true  (BUG: should be false)
user.accesses.any? # => true  (BUG: should be empty)
user.identity_id   # => nil   (nullified, but deactivation never ran)
```

## The Fix

Add `prepend: true` to ensure `deactivate_users` runs before the association's nullify callback:

```ruby
before_destroy :deactivate_users, prepend: true
```

## Optional Enhancement: User Reactivation

This PR also includes changes to enable reactivating deactivated users when they rejoin via join
code. This is separable from the bug fix if you prefer a minimal change.

### How it works:
- `User#deactivate` no longer sets `identity: nil` - the link is preserved
- When Identity is destroyed, `dependent: :nullify` still severs the link (after deactivation now
  runs)
- When UsersController calls deactivate, the identity link remains, allowing
  `Identity::Joinable#join` to find and reactivate the existing user record.

If you prefer the original behavior (deactivated users cannot rejoin the same account), you can:
1. Accept only the `prepend: true` fix in `identity.rb`
2. Keep `identity: nil` in `User#deactivate`, but understand this causes constraint issues that are managed by `find_or_create_by!` in `Joinable#join`
3. Skip the `joinable.rb` changes

## Changes

| File          | Change                                             | Category    |
|---------------|----------------------------------------------------|-------------|
| `identity.rb` | `prepend: true` on callback                        | Bug fix     |
| `user.rb`     | Remove `identity: nil`, remove transaction wrapper | Enhancement |
| `joinable.rb` | Reactivate inactive users on rejoin                | Enhancement |
