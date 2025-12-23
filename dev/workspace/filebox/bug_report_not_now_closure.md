# Bug Report: Closed cards from NOT NOW missing from `indexed_by=closed` filter

**Date:** 2025-12-21
**Discovered via:** API testing
**Severity:** Medium (data appears correctly but filtering fails)

## Summary

Cards closed directly from NOT NOW state retain their `not_now` record, causing them to be excluded from the `indexed_by=closed` filter results. The cards show `closed: true` in individual API responses but don't appear in filtered lists.

## Reproduction Steps

1. Create a card (starts in MAYBE?/triage)
2. Move card to NOT NOW: `POST /cards/:number/not_now`
3. Close the card directly: `POST /cards/:number/closure`
4. Query closed cards: `GET /cards?indexed_by=closed`

**Expected:** Card appears in closed list
**Actual:** Card is missing from closed list

## Root Cause

The `Card#close` method in `app/models/card/closeable.rb` does not clean up the `not_now` record:

```ruby
def close(user: Current.user)
  unless closed?
    transaction do
      create_closure! user: user
      track_event :closed, creator: user
    end
  end
end
```

Meanwhile, the `Filter#cards` method in `app/models/filter.rb` excludes cards with `not_now` records:

```ruby
result = result.where.missing(:not_now) unless include_not_now_cards?
```

The `include_not_now_cards?` method only returns `true` when `indexed_by.not_now?`, so closed cards with orphaned `not_now` records are filtered out.

## Affected Code Paths

- **API:** `POST /:account/cards/:number/closure`
- **UI:** Clicking "Mark as Done" on a card in NOT NOW column
- Both paths call `Card#close` which has the bug

## Verified Behavior

Other transitions properly clean up via `resume`:
- `send_back_to_triage` → calls `resume` → destroys `not_now`
- `triage_into(column)` → calls `resume` → destroys `not_now`
- `postpone` → calls `send_back_to_triage` first

Only `close` skips this cleanup.

## Suggested Fix

In `app/models/card/closeable.rb`, add `not_now&.destroy` to the `close` method:

```ruby
def close(user: Current.user)
  unless closed?
    transaction do
      not_now&.destroy  # Clean up NOT NOW state
      create_closure! user: user
      track_event :closed, creator: user
    end
  end
end
```

## Data Cleanup

Existing orphaned records can be cleaned with:

```ruby
# Find cards with both closure and not_now records
Card.joins(:closure, :not_now).find_each do |card|
  card.not_now.destroy
end
```

## Test Cases to Add

```ruby
test "close card from triage column" do
  card = cards(:logo)
  assert_equal columns(:writebook_triage), card.column

  card.close
  assert card.closed?
end

test "close card from active column" do
  card = cards(:text)
  assert_equal columns(:writebook_in_progress), card.column

  card.close
  assert card.closed?
end

test "close card from NOT NOW" do
  card = cards(:logo)

  card.postpone
  assert card.postponed?
  assert card.not_now.present?

  card.close
  assert card.closed?
  assert_nil card.reload.not_now
end
```

## Resolution

**Status:** Fixed
**Date:** 2025-12-23

**Fix Applied:**
- Added `not_now&.destroy` to `Card#close` in `app/models/card/closeable.rb`
- Pattern mirrors `resume` method in `app/models/card/postponable.rb`

**Tests Added:**
- Three close transition tests in `test/models/card/closeable_test.rb`
- Tests verify closing works from all contexts: triage, active column, and NOT NOW

**Verification:**
- API tested: Card moved to NOT NOW → closed → appeared in `indexed_by=closed`
- Test suite: All 6 closeable tests pass, all 21 related filter/postponable tests pass