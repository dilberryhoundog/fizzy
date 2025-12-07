# PR Draft v2 - Full (Bug Fix + Enhancement)

**Title:** Fix Identity#destroy callback ordering and enable user reactivation

## Summary

This PR fixes a bug where `Identity#destroy` fails to properly deactivate users due to callback ordering, and includes an enhancement to enable user reactivation when rejoining an account.

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

## Historical Context

Looking at the git history, this appears to stem from the membership refactor:

| Date   | Commit    | Change                                                                           |
|--------|-----------|----------------------------------------------------------------------------------|
| Apr 22 | `7124835` | **No long transactions!** - DHH removes transaction from deactivate              |
| Nov 13 | `edf837f` | **Drop memberships** - Identity now has `has_many :users, dependent: :nullify`   |
| Nov 13 | `34d83aa` | **Fix tests** - Added `identity: nil` to `User#deactivate`, transaction re-added |
| Dec 3  | `6e9381a` | **Fix race condition** - Changed `create!` to `find_or_create_by!` in `join`     |

The `identity: nil` in `User#deactivate` was added as a quick test fix after dropping memberships, but it created a cascade:

1. Severing the identity link allows "duplicate" users (NULL ≠ NULL in unique constraint)
2. This led to the race condition fix using `find_or_create_by!`
3. But the callback ordering bug remained unaddressed

### On Transactions

DHH's original reasoning for removing the transaction from `deactivate` (commit `7124835`):

> "If you intend to deactivate someone, and the process fails mid process, so you only delete some sessions, or some accesses, you are actually fine. The system is never left in an incomplete state. And that's really the only time we should be using transactions with sqlite3 -- to prevent actual data integrity issues."

This reasoning still applies - without `identity: nil`, all operations in `deactivate` are independently safe:
- `accesses.destroy_all` - partial completion is fine
- `update! active: false` - atomic
- `close_remote_connections` - side effect, doesn't affect data integrity

The transaction was re-added alongside `identity: nil` but isn't needed if we remove that assignment.

## Changes

### Bug Fix

**`identity.rb`**: Add `prepend: true` to ensure deactivation runs before nullification

```diff
-  before_destroy :deactivate_users
+  before_destroy :deactivate_users, prepend: true
```

### Enhancement: User Reactivation

**`user.rb`**: Remove `identity: nil` and transaction wrapper - preserves identity link so rejoining users can be found. This also ensures Identity destroy works correctly and avoids unique constraint issues.

**`joinable.rb`**: Handle reactivation - if an inactive user with matching identity exists, reactivate them and re-grant board access

## Behavior Change

| Scenario                   | Before                                           | After                                           |
|----------------------------|--------------------------------------------------|-------------------------------------------------|
| Identity destroyed         | Users left active with orphaned accesses         | Users properly deactivated first                |
| Admin removes user         | User gets `identity: nil`, fresh start on rejoin | User keeps identity link, same record on rejoin |
| User rejoins via join code | New user record created                          | Existing record reactivated with history intact |
