# Upstream PR: Fix rich text images with S3-compatible storage

## Branch

Create from `main` (upstream): `fix/rich-text-image-cors-and-urls`

## Title

Fix rich text image display with S3-compatible storage

## Body

## Summary

- Fix service worker CORS credentials to work with cross-origin Active Storage redirects to S3/R2/GCS/Azure
- Fix ActionText attachment URLs missing account prefix for multi-tenant routing

## Problem

Two issues affecting self-hosted deployments using S3-compatible storage (R2, MinIO, etc.):

1. **Service worker CORS failure**: The `turbo-offline` service worker inherits `credentials: "include"` from the original request when fetching Active Storage redirect URLs. After following the cross-origin redirect to cloud storage, the browser requires `Access-Control-Allow-Credentials: true` in the response, which S3-compatible stores cannot return with specific origin CORS policies.

2. **ActionText attachment URLs missing account prefix**: `to_rich_text_attributes` generates blob URLs without the account `script_name` prefix (e.g., `/rails/active_storage/blobs/redirect/...` instead of `/1234567/rails/active_storage/blobs/redirect/...`). The `AccountSlug::Extractor` middleware can't route these, returning 404. The editor (Lexxy) uses these URLs as `<img src>` when re-editing rich text, so images appear broken in the editor despite displaying correctly on the show view.

Root cause: upstream commit `235890e66` switched ActionText attachment URLs from absolute to relative for portability, but the relative URLs lack the `script_name` prefix needed by multi-tenant routing.

## Changes

**`app/views/pwa/service_worker.js.erb`** (line 46):

```diff
-    fetchOptions: { mode: "cors" }
+    fetchOptions: { mode: "cors", credentials: "same-origin" }
```

Sends credentials to Rails (needed for auth) but strips them on cross-origin redirects to cloud storage.

**`config/initializers/active_storage.rb`** (line 17):

```diff
-      super.merge url: Rails.application.routes.url_helpers.polymorphic_url(self, only_path: true)
+      super.merge url: Rails.application.routes.url_helpers.polymorphic_url(self, only_path: true, script_name: Current.account&.slug)
```

Adds account slug prefix so URLs route correctly through the multi-tenant middleware. Nil-safe — when `Current.account` is nil, behaves identically to before.

## Safety

- **Disk service**: Same-origin redirects still receive credentials; account-prefixed URLs route correctly through middleware
- **S3/R2/GCS/Azure**: Cross-origin credentials stripped (desired); blob URLs use service's own URL generation (unaffected by script_name)
- **Background jobs**: `AccountTenanted` mixin serializes/restores `Current.account`
- **Non-request contexts**: `Current.account&.slug` returns nil, no behavior change
- **Existing pattern**: Webhook delivery already uses `script_name: account.slug` with `polymorphic_url`

## Test plan

- [ ] Verify images display correctly in rich text show views (all storage services)
- [ ] Verify images load in Lexxy editor when re-editing rich text content
- [ ] Verify service worker caches storage blobs without CORS errors
- [ ] Run existing `test/integration/active_storage_authorization_test.rb`
- [ ] Run existing `test/models/storage/attachment_tracking_test.rb`

## Reproduction

- **Storage**: Cloudflare R2 with private blobs served via signed URLs
- **Tenant config**: Single-tenant deployment (`MULTI_TENANT=false`), but still uses path-based account slug routing
- **Active Storage mode**: Redirect mode (default, blobs served via 302 to storage provider)
- **Editor**: Latest Lexxy gallery implementation (0.9.5) triggering the service worker to cache image representations

## Note

Existing ActionText content with broken URLs will fix itself when re-saved.
