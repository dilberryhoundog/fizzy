# Fizzy API Quirks and Notes

**Date:** 2025-12-21
**Context:** Discovered during API exploration and testing

---

## 1. Card Number vs Card ID in URLs

**Issue:** The API uses card **number** (integer) in URLs, not the card **ID** (UUID).

**What happens:** If you accidentally pass the UUID in a URL like `/cards/:card_id/comments`, Rails will coerce the string to an integer. A UUID like `03f9aojhjgeafuvzog6pl8ziv` becomes `3` (parsing stops at first non-numeric char after leading zeros).

**Example:**
```bash
# WRONG - uses UUID, comment goes to card #3
POST /cards/03f9aojhjgeafuvzog6pl8ziv/comments

# CORRECT - uses card number
POST /cards/12/comments
```

**Affected endpoints:** All card-scoped routes (`/cards/:card_id/...`)

**Root cause:** `CardScoped` concern uses `find_by!(number: params[:card_id])`

---

## 2. Special Columns Have No JSON API

**Issue:** The three built-in columns (NOT NOW, MAYBE?, DONE) are not accessible via JSON API.

| Column  | Internal name | Endpoint                      | JSON Support |
|---------|---------------|-------------------------------|--------------|
| NOT NOW | `not_nows`    | `/boards/:id/columns/not_now` | HTML only    |
| MAYBE?  | `streams`     | `/boards/:id/columns/stream`  | HTML only    |
| DONE    | `closeds`     | `/boards/:id/columns/closed`  | HTML only    |

**Workaround:** Use card filters to query by state:
```bash
GET /cards?indexed_by=closed    # DONE cards
GET /cards?indexed_by=not_now   # NOT NOW cards
GET /cards                      # MAYBE?/triage cards (default)
```

**Note:** `GET /boards/:id/columns` only returns user-created columns, not the built-in ones.

---

## 3. Accept Header Required for JSON API

**Issue:** POST/PUT/DELETE requests without `Accept: application/json` header fail with CSRF errors.

**Error:** `ActionController::InvalidAuthenticityToken - Can't verify CSRF token authenticity`

**Solution:** Always include both headers:
```bash
curl -X POST \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \  # Required!
  -d '{"comment":{"body":"Hello"}}' \
  http://fizzy.localhost:3006/897362095/cards/12/comments
```

---

## 4. Card Response Varies by Column State

**Issue:** The `column` field only appears when a card is in a user-created column.

**In user-created column:**
```json
{
  "number": 12,
  "closed": false,
  "column": {
    "id": "03f9ayjb2v45ry02qitzj0ab6",
    "name": "Staging",
    "color": {"name": "Aqua", "value": "var(--color-card-5)"}
  }
}
```

**In triage (MAYBE?) or after moving to NOT NOW:**
```json
{
  "number": 12,
  "closed": false
  // no "column" field
}
```

**In DONE:**
```json
{
  "number": 12,
  "closed": true
  // no "column" field
}
```

**Implication:** Check for presence of `column` field, don't assume it exists.

---

## 5. Card Workflow Endpoints

The API provides endpoints to move cards between special columns:

| Action                     | Method | Endpoint                                    |
|----------------------------|--------|---------------------------------------------|
| Move to NOT NOW            | POST   | `/cards/:number/not_now`                    |
| Move to triage (MAYBE?)    | DELETE | `/cards/:number/triage`                     |
| Move from triage to column | POST   | `/cards/:number/triage` + `column_id` param |
| Close (DONE)               | POST   | `/cards/:number/closure`                    |
| Reopen                     | DELETE | `/cards/:number/closure`                    |

**Note:** There's no direct endpoint to move from NOT NOW back to triage - use `DELETE /triage` which internally calls `send_back_to_triage`.

---

## 6. Tags Created On-the-fly

**Behavior:** The tagging endpoint creates tags if they don't exist.

```bash
POST /cards/12/taggings
{"tag_title": "new-tag"}  # Creates tag if it doesn't exist
```

The `tag_title` parameter strips leading `#` automatically.

---

## 7. Comments Endpoint Returns Chronologically

**Behavior:** `GET /cards/:number/comments` returns comments oldest-first (chronologically), not newest-first.

This matches typical conversation display but differs from card lists which show newest first.

---

## 8. Pagination via Link Header

**Behavior:** Paginated endpoints use the `Link` header with `rel="next"`:

```
Link: <http://fizzy.localhost:3006/897362095/cards?page=2>; rel="next"
```

Check for this header to determine if more pages exist. Dynamic page sizing means initial pages return fewer results.
