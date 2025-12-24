# Fizzy API Quick Start

## Credentials

```bash
TOKEN="7kR2kW8qBbfnAkEFqi9tE1FA"
ACCOUNT="897362095"
BASE="http://fizzy.localhost:3006/${ACCOUNT}"
```

## Request Formats

### GET (Read)

```bash
curl -s \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Accept: application/json" \
  "${BASE}/cards" | jq .
```

### POST (Create)

```bash
curl -s -X POST \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{"card":{"title":"My Card"}}' \
  "${BASE}/boards/{board_id}/cards" | jq .
```

### PUT (Update)

```bash
curl -s -X PUT \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{"card":{"title":"Updated Title"}}' \
  "${BASE}/cards/{number}" | jq .
```

### DELETE

```bash
curl -s -X DELETE \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Accept: application/json" \
  "${BASE}/cards/{number}/closure"
```

---

## Common Workflows

### Identity & Account

```bash
# Get identity and accounts
curl -s -H "Authorization: Bearer ${TOKEN}" -H "Accept: application/json" \
  "http://fizzy.localhost:3006/my/identity" | jq .
```

### Boards

```bash
# List boards
curl -s -H "Authorization: Bearer ${TOKEN}" -H "Accept: application/json" \
  "${BASE}/boards" | jq .

# Get board with columns
curl -s -H "Authorization: Bearer ${TOKEN}" -H "Accept: application/json" \
  "${BASE}/boards/{board_id}/columns" | jq .
```

### Cards

```bash
# List all cards
curl -s -H "Authorization: Bearer ${TOKEN}" -H "Accept: application/json" \
  "${BASE}/cards" | jq .

# Get single card (by number)
curl -s -H "Authorization: Bearer ${TOKEN}" -H "Accept: application/json" \
  "${BASE}/cards/{number}" | jq .

# Filter cards
curl -s -H "Authorization: Bearer ${TOKEN}" -H "Accept: application/json" \
  "${BASE}/cards?indexed_by=closed" | jq .
#   indexed_by: all, closed, not_now, stalled, postponing_soon, golden

# Create card
curl -s -X POST \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{"card":{"title":"New Card","description":"Card body"}}' \
  "${BASE}/boards/{board_id}/cards"
```

### Card State Transitions

```bash
# Move to NOT NOW
curl -s -X POST \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Accept: application/json" \
  "${BASE}/cards/{number}/not_now"

# Send back to triage (MAYBE?)
curl -s -X DELETE \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Accept: application/json" \
  "${BASE}/cards/{number}/triage"

# Move from triage to column
curl -s -X POST \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{"column_id":"{column_id}"}' \
  "${BASE}/cards/{number}/triage"

# Close card (DONE)
curl -s -X POST \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Accept: application/json" \
  "${BASE}/cards/{number}/closure"

# Reopen card
curl -s -X DELETE \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Accept: application/json" \
  "${BASE}/cards/{number}/closure"
```

### Comments

```bash
# List comments on card
curl -s -H "Authorization: Bearer ${TOKEN}" -H "Accept: application/json" \
  "${BASE}/cards/{number}/comments" | jq .

# Add comment
curl -s -X POST \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{"comment":{"body":"My comment"}}' \
  "${BASE}/cards/{number}/comments"
```

### Tags

```bash
# List tags
curl -s -H "Authorization: Bearer ${TOKEN}" -H "Accept: application/json" \
  "${BASE}/tags" | jq .

# Toggle tag on card (creates if doesn't exist)
curl -s -X POST \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{"tag_title":"my-tag"}' \
  "${BASE}/cards/{number}/taggings"
```

### Assignments

```bash
# Toggle assignment
curl -s -X POST \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{"assignee_id":"{user_id}"}' \
  "${BASE}/cards/{number}/assignments"
```

---

## Tips

1. **Always use card number** in URLs, not UUID
2. **Accept header required** for POST/PUT/DELETE to avoid CSRF errors
3. **Pipe to `jq .`** for readable JSON output
4. **Check HTTP status** with `-w "\nHTTP: %{http_code}"`
5. **204 No Content** is success for most write operations

---

## Claude Code Permissions

Settings in `.claude/settings.json`:

```json
{
  "permissions": {
    "allow": [
      "Bash(curl -s:*)"
    ],
    "ask": [
      "Bash(curl -s -X POST:*)",
      "Bash(curl -s -X PUT:*)",
      "Bash(curl -s -X DELETE:*)"
    ]
  }
}
```

- **GET requests** (`curl -s`) → auto-allowed
- **POST/PUT/DELETE** → prompts for confirmation
