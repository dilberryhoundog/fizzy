# Events API Documentation

> Add this section to docs/API.md

## Events

Events represent actions that have occurred on cards and comments. Use events to track activity history, build integrations, or implement automation based on card movements.

### `GET /:account_slug/events`

Returns a paginated list of events you have access to, sorted by most recent first.

__Query Parameters:__

| Parameter       | Description                                       |
|-----------------|---------------------------------------------------|
| `board_ids[]`   | Filter by board ID(s)                             |
| `action`        | Filter by event action type                       |
| `actions[]`     | Filter by multiple action types                   |
| `creator_ids[]` | Filter by event creator user ID(s)                |
| `card_ids[]`    | Filter to events for specific card ID(s)          |
| `since`         | Events created after this time (ISO 8601 format)  |
| `until`         | Events created before this time (ISO 8601 format) |

__Action Types:__

| Action                     | Description                                        |
|----------------------------|----------------------------------------------------|
| `card_assigned`            | User was assigned to a card                        |
| `card_unassigned`          | User was unassigned from a card                    |
| `card_published`           | Card was published (moved from draft)              |
| `card_closed`              | Card was closed (moved to Done)                    |
| `card_reopened`            | Closed card was reopened                           |
| `card_postponed`           | Card was moved to Not Now                          |
| `card_auto_postponed`      | Card was automatically postponed due to inactivity |
| `card_triaged`             | Card was moved to a column                         |
| `card_sent_back_to_triage` | Card was sent back to Maybe?                       |
| `card_board_changed`       | Card was moved to a different board                |
| `card_title_changed`       | Card title was changed                             |
| `comment_created`          | Comment was added to a card                        |

__Response:__

```json
[
  {
    "id": "03f5v9zo9qlcwwpyc0ascnikz",
    "action": "card_triaged",
    "created_at": "2025-12-24T10:30:00.000Z",
    "particulars": {
      "particulars": {
        "column": "In Progress"
      }
    },
    "eventable_type": "Card",
    "board": {
      "id": "03f5v9zkft4hj9qq0lsn9ohcm",
      "name": "Fizzy",
      "all_access": true,
      "created_at": "2025-12-05T19:36:35.534Z",
      "url": "http://fizzy.localhost:3006/897362094/boards/03f5v9zkft4hj9qq0lsn9ohcm"
    },
    "creator": {
      "id": "03f5v9zjw7pz8717a4no1h8a7",
      "name": "David Heinemeier Hansson",
      "role": "owner",
      "active": true,
      "email_address": "david@example.com",
      "created_at": "2025-12-05T19:36:35.401Z",
      "url": "http://fizzy.localhost:3006/897362094/users/03f5v9zjw7pz8717a4no1h8a7"
    },
    "card": {
      "id": "03f5vaeq985jlvwv3arl4srq2",
      "number": 1,
      "title": "First!",
      "status": "published",
      "url": "http://fizzy.localhost:3006/897362094/cards/1"
    },
    "url": "http://fizzy.localhost:3006/897362094/cards/1"
  }
]
```

__Particulars by Action Type:__

The `particulars` field contains action-specific data:

| Action               | Particulars                                  |
|----------------------|----------------------------------------------|
| `card_triaged`       | `{ "column": "Column Name" }`                |
| `card_board_changed` | `{ "old_board": "...", "new_board": "..." }` |
| `card_title_changed` | `{ "old_title": "...", "new_title": "..." }` |
| `card_assigned`      | `{ "assignee_ids": ["..."] }`                |
| `card_unassigned`    | `{ "assignee_ids": ["..."] }`                |

__Example - Get column movement history for a card:__

```bash
curl -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/json" \
  "https://app.fizzy.do/123456/events?action=card_triaged&card_ids[]=abc123"
```

__Example - Get all activity in the last 24 hours:__

```bash
curl -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/json" \
  "https://app.fizzy.do/123456/events?since=$(date -u -v-1d +%Y-%m-%dT%H:%M:%SZ)"
```
