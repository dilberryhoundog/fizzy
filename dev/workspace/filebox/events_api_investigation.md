# Events API Investigation Summary

## Overview

Investigation into adding an API endpoint for events, following existing Fizzy API patterns.

## Key Finding: Account Scoping is Compatible

Events are fully compatible with account scoping:

```ruby
# events table has account_id (schema.rb:282)
t.uuid "account_id", null: false

# Event model (event.rb:4)
belongs_to :account, default: -> { board.account }
belongs_to :board

# Board has_many :events (board.rb:10)
has_many :events

# User accesses boards via accesses (user/accessor.rb:6)
has_many :boards, through: :accesses
```

**Access chain:** `User → boards (through accesses) → events`

---

## Possible Query Parameters

### Definitely Possible

| Parameter | Rationale |
|-----------|-----------|
| `board_ids[]` | Events belong_to board, direct filter |
| `action` | Filter by event type (e.g., `card_triaged`) |
| `actions[]` | Multiple actions |
| `since` / `after` | Events after timestamp (common pattern) |
| `until` / `before` | Events before timestamp |
| `creator_ids[]` | Events have creator_id |

### Possible with Join

| Parameter | Rationale |
|-----------|-----------|
| `card_ids[]` | Events have `eventable_id` where `eventable_type = 'Card'` |
| `card_number` | Join through cards table |

### Not Directly Possible

| Parameter | Why |
|-----------|-----|
| `column_id` | Column name is stored in `particulars` JSON, not as FK |
| `column_name` | Would require JSON query on particulars |

**Note:** Column filtering would require querying `particulars->>'$.particulars.column'` which is possible but less efficient.

---

## Why Events May Not Have Been in Original API

### 1. Volume Concerns
- Events accumulate rapidly (every card action creates one)
- A busy account could have thousands of events per day
- Pagination alone may not be sufficient for efficient polling

### 2. Specificity/Parsing Complexity
- Events are polymorphic (`eventable` can be Card or Comment)
- The `particulars` JSON field has varying structure per action type
- Consumers need to understand 11+ different action types
- More complex to document and consume than entity-based endpoints

### 3. Webhook Alternative
- Webhooks already exist for real-time event notification
- Push-based (webhooks) vs pull-based (API polling) - webhooks preferred for events
- Events API would be redundant for real-time use cases

### 4. Design Philosophy
- API focuses on current state of entities (cards, boards, users)
- Events represent history/activity - different access pattern
- Timeline view in UI is day-based, not raw event list

### 5. Missing `particulars` in Webhook
- The webhook payload (`webhooks/event.json.jbuilder`) doesn't include `particulars`
- This is the gap that makes an Events API valuable for automation
- Could alternatively fix the webhook payload instead

---

## Recommended Approach

For automation/integration use cases, two options:

### Option A: Add Events API (more flexible)
- Full history access
- Supports polling patterns
- Can filter by action, board, time range
- Includes `particulars` for column tracking

### Option B: Enhance Webhook Payload (simpler)
- Add `particulars` to `webhooks/event.json.jbuilder`
- Real-time push notifications
- No polling required
- Less infrastructure for consumers

---

## Implementation Files

See `filebox/events_api/` for proposed implementation:
- `app/models/user/accessor.rb` - Add accessible_events association
- `app/controllers/events_controller.rb` - Extended with JSON support
- `app/views/events/index.json.jbuilder` - List view
- `app/views/events/_event.json.jbuilder` - Event partial

---

## Existing Patterns Used

| Pattern | Source |
|---------|--------|
| Pagination | `geared_pagination` gem → `set_page_and_extract_portion_from` |
| JSON format | `respond_to { format.json }` |
| Caching | `json.cache! record do` |
| Partials | `partial: "model/model", as: :model` |
| Auth | Bearer token via `Identity::AccessToken` |
| Tests | `test/controllers/api_test.rb` pattern |
