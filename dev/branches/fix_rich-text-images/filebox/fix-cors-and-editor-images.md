# Fix: CORS + Editor Image Display

Two fixes for broken image display on self-hosted Fizzy with Cloudflare R2 storage.

## Fix 1: Service Worker CORS Credentials

**File:** `app/views/pwa/service_worker.js.erb` (line 46)

```diff
-    fetchOptions: { mode: "cors" }
+    fetchOptions: { mode: "cors", credentials: "same-origin" }
```

**Problem:** The turbo-offline service worker inherits `credentials: "include"` from the original request when fetching Active Storage redirect URLs. After following the cross-origin redirect to R2, the browser requires `Access-Control-Allow-Credentials: true` in the response, which R2 (and S3-compatible stores) cannot return.

**Fix:** `credentials: "same-origin"` sends credentials to Rails (needed for auth) but strips them on the cross-origin redirect to R2, allowing R2's standard CORS config to work.

## Fix 2: ActionText Attachment URL Missing Account Prefix

**File:** `config/initializers/active_storage.rb` (line 17)

```diff
-      super.merge url: Rails.application.routes.url_helpers.polymorphic_url(self, only_path: true)
+      super.merge url: Rails.application.routes.url_helpers.polymorphic_url(self, only_path: true, script_name: Current.account&.slug)
```

**Problem:** `to_rich_text_attributes` generates blob URLs without the account prefix (e.g., `/rails/active_storage/blobs/redirect/...`). The `AccountSlug::Extractor` middleware can't route these — returns 404. Lexxy uses these URLs as `<img src>` when re-editing rich text content, so images appear blank in the editor despite displaying correctly on the show view (which renders server-side with the correct prefix).

**Fix:** Adding `script_name: Current.account&.slug` produces the correct path (e.g., `/1/rails/active_storage/blobs/redirect/...`).

**Note:** Existing ActionText content has the broken URLs serialized in the database. Images will fix themselves when the content is re-saved.

## R2 CORS Configuration (Required)

Cloudflare R2 bucket `bizzy-storage` must have this CORS policy:

```json
[
  {
    "AllowedOrigins": [
      "https://bizzy.grahams.coffee",
      "https://staging.bizzy.grahams.coffee"
    ],
    "AllowedMethods": ["GET", "PUT", "POST", "DELETE", "HEAD"],
    "AllowedHeaders": ["*"],
    "ExposeHeaders": ["ETag"],
    "MaxAgeSeconds": 3600
  }
]
```

## Root Cause

Introduced by upstream commit `235890e66` (Rosa Gutierrez, Jan 2026) which switched ActionText attachment URLs from absolute to relative for portability. The relative URLs lack the account `script_name` prefix needed by the multi-tenant routing middleware. Combined with the new gallery feature in Lexxy that uses transformed image representations, the service worker's CORS handling also broke.

Both issues are upstream bugs affecting any self-hosted Fizzy deployment using S3-compatible storage.
