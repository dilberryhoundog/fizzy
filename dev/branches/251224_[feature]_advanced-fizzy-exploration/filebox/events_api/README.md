# Events API Proposal

Proposed implementation files for adding an Events API endpoint to Fizzy.

## Files

```
events_api/
├── app/
│   ├── controllers/
│   │   └── events_controller.rb      # Extended controller with JSON support
│   ├── models/
│   │   └── user/
│   │       └── accessor.rb           # Add accessible_events association
│   └── views/
│       └── events/
│           ├── index.json.jbuilder   # List view
│           └── _event.json.jbuilder  # Event partial with particulars
├── test/
│   └── controllers/
│       └── events_controller_api_test.rb
└── README.md
```

## Implementation Steps

1. **Add association** - Edit `app/models/user/accessor.rb` to add `has_many :accessible_events`
2. **Extend controller** - Replace `app/controllers/events_controller.rb` with version that handles JSON
3. **Add views** - Copy jbuilder files to `app/views/events/`
4. **Add tests** - Copy test file to `test/controllers/`
5. **Update API docs** - Add Events section to `docs/API.md`

## Key Feature: Particulars

The `particulars` field is included in the response, enabling column tracking:

```json
{
  "id": "abc123",
  "action": "card_triaged",
  "created_at": "2025-12-24T10:30:00Z",
  "particulars": {
    "particulars": {
      "column": "In Progress"
    }
  },
  "board": { ... },
  "creator": { ... },
  "card": { ... }
}
```

## Query Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `board_ids[]` | array | Filter by board IDs |
| `action` | string | Filter by single action type |
| `actions[]` | array | Filter by multiple action types |
| `creator_ids[]` | array | Filter by event creator |
| `card_ids[]` | array | Filter by card IDs (Card events only) |
| `since` | datetime | Events created after this time (ISO 8601) |
| `until` | datetime | Events created before this time (ISO 8601) |

## Action Types

```
card_assigned
card_unassigned
card_published
card_closed
card_reopened
card_postponed
card_auto_postponed
card_triaged
card_sent_back_to_triage
card_board_changed
card_title_changed
comment_created
```
