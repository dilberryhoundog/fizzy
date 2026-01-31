# Multi-Tenancy Investigation

**Date:** 2026-01-31
**Branch:** `refactor/multi-tenant-investigation`

## Overview

Fizzy uses a hybrid tenancy model. URL path-based account scoping is always active via middleware, while a separate `MULTI_TENANT` flag controls whether new accounts can be created (signup gating). This separation means the routing and data isolation infrastructure is always present — only the signup door is opened or closed.

---

## 1. Configuration Layer

### How the tenant mode flag flows

```
config/deploy.yml           →  MULTI_TENANT: false (env var, default for self-hosted)
config/environments/test.rb →  config.x.multi_tenant.enabled = true
saas/config/environments/   →  config.x.multi_tenant.enabled = true

                ↓

config/initializers/multi_tenant.rb
  Account.multi_tenant = ENV["MULTI_TENANT"] == "true" || config.x.multi_tenant.enabled == true

                ↓

Account.multi_tenant (class-level accessor, default: false)
Account.accepting_signups? → multi_tenant || Account.none?
```

The env var `MULTI_TENANT` in `config/deploy.yml:34` is the operator-facing control. It's set to `false` by default. The `config.x.multi_tenant.enabled` config is used by test and SaaS environment files to force multi-tenant mode on without an env var.

The initializer at `config/initializers/multi_tenant.rb` runs `after_initialize` and sets the `Account.multi_tenant` class accessor from either source.

### What accepting_signups? controls

`Account.accepting_signups?` (defined in `app/models/account/multi_tenantable.rb`) is the single predicate that gates tenant creation. It returns `true` when:

1. `Account.multi_tenant` is `true` (multi-tenant mode), OR
2. `Account.none?` is `true` (no accounts exist yet — bootstrap escape hatch)

This predicate is checked in four places:

| Location | Effect when `false` |
|---|---|
| `SignupsController#enforce_tenant_limit` | Redirects `/signup/new` to `/sessions/new` |
| `SessionsController#create` | Unknown emails get a fake magic link instead of creating an identity |
| `sessions/new.html.erb` view | Hides the "Sign up" link and alternate text |
| `Account::Cancellable#cancellable?` | Prevents account deletion in single-tenant mode |

### The bootstrap escape hatch

When `Account.none?` returns true (fresh database), `accepting_signups?` is true regardless of the `MULTI_TENANT` flag. This allows the first account to be created even in single-tenant mode. Once an account exists, the door closes.

---

## 2. URL Path Tenancy (Always Active)

### AccountSlug middleware

**File:** `config/initializers/tenanting/account_slug.rb`

The `AccountSlug::Extractor` middleware is always inserted into the Rack stack (after `Rack::TempfileReaper`). It works by:

1. Matching a 7+ digit number prefix in the request path: `/(\d{7,})/`
2. Moving the matched prefix from `PATH_INFO` to `SCRIPT_NAME`
3. Setting `env["fizzy.external_account_id"]` from the decoded slug
4. Wrapping the request in `Current.with_account(account)` or `Current.without_account`

This means Rails sees the app as "mounted" at the account slug path. All URL helpers automatically include the slug via `script_name`. Routes are the same for every tenant — only the prefix changes.

### Account slug encoding

```ruby
# Account model
def slug
  "/#{AccountSlug.encode(external_account_id)}"
end

# AccountSlug module
PATTERN = /(\d{7,})/
FORMAT = "%07d"
```

Account external IDs are 7+ digit integers. The slug is just the zero-padded integer prefixed with `/`. No base36, no hashing — direct encoding.

### Turbo Streams tenant scoping

**File:** `config/initializers/tenanting/turbo.rb`

When Turbo renders streams in background jobs, the `TurboStreamsJobExtensions` module injects `script_name: Current.account.slug` into the renderer. This ensures WebSocket broadcasts target the correct tenant's URL namespace.

---

## 3. Current Context Resolution

**File:** `app/models/current.rb`

The `Current` class uses cascading setters to resolve the request context:

```
Middleware sets:     Current.account   (from URL slug)
Authentication sets: Current.session   (from signed cookie)
  → auto-sets:      Current.identity  (from session.identity)
    → auto-sets:    Current.user      (from identity.users.find_by(account: account))
```

The key line is in `identity=`: it looks up the User belonging to the current account for this identity. This is how one email (Identity) maps to the right User record per tenant.

### disallow_account_scope

Controllers that operate outside tenant scope (signup, session, admin) use `disallow_account_scope` which:
1. Skips `require_account` before_action
2. Adds `redirect_tenanted_request` which redirects to root if a tenant slug is present

This prevents users from accessing `/1234567/signup` — signup always happens at the root path.

---

## 4. Signup Flow (New Account Creation)

```
GET /signup/new
  → enforce_tenant_limit (redirects to login if !accepting_signups?)
  → User enters email

POST /signup
  → Signup.new(email).create_identity
  → Identity.find_or_create_by!(email_address:)
  → identity.send_magic_link(for: :sign_up)
  → redirect to magic link entry page

POST /sessions/magic_links
  → MagicLink.consume(code) validates the 6-char code
  → start_new_session_for(identity)
  → redirect to /signups/completions/new (new identity detected)

POST /signups/completions
  → signup.complete
    → Account.create_with_owner(account: {...}, owner: {name:, identity:})
      → creates Account with auto-assigned external_account_id
      → creates System user (role: :system)
      → creates Owner user (role: :owner, verified_at: now)
    → account.setup_customer_template (creates Playground board + onboarding cards)
  → redirect to landing_url(script_name: account.slug)
```

### Account.create_with_owner

**File:** `app/models/account.rb:18-25`

This is the only path for creating new accounts from the UI. It always creates:
1. The Account record (with auto-assigned `external_account_id` from `ExternalIdSequence`)
2. A System User for automated actions
3. An Owner User linked to the signing-up identity

---

## 5. Join Code Flow (Joining Existing Account)

```
GET /join/:code
  → Looks up Account::JoinCode by code
  → Shows join form (email entry)

POST /join/:code
  → Identity.find_or_initialize_by(email_address:)
  → join_code.redeem_if { |account| identity.join(account) }
    → account.users.find_or_create_by!(identity: self)
    → Reactivates if previously deactivated
    → Increments usage_count
  → Routes based on context:
    → Same identity & setup → landing
    → Same identity & not setup → verification page
    → Different identity → terminate session, send magic link, redirect to verification
```

### Identity::Joinable#join

**File:** `app/models/identity/joinable.rb`

The `join` method is idempotent — it safely handles:
- New user creation (returns `true`, increments join code usage)
- Existing active user (returns `false`, no-op)
- Deactivated user reactivation (returns `false`, restores board access)

### Join code lifecycle

- Auto-created when account is created
- 12-char base58 code, displayed as 4-4-4 with hyphens
- Usage limit defaults to 10 billion (effectively unlimited)
- Can be reset (generates new code, resets count)
- Scoped to account (looked up within `Current.account` context)

---

## 6. Account Selection Screen

**File:** `app/controllers/sessions/menus_controller.rb`

When an authenticated identity has multiple accounts, the menu shows at `/sessions/menus/show`:
- Lists all active accounts for the identity
- Each account links to `landing_path(script_name: account.slug)`
- Always shows "Sign up for a new Fizzy account" link (unconditional — not gated by `accepting_signups?`)
- If identity has exactly one account, auto-redirects to it

**Observation for Task 3:** The account selection menu currently always shows the signup link. This would need to be conditionally hidden when signups are restricted.

---

## 7. Seeds and First Deploy

**File:** `db/seeds.rb`

The `bin/setup` script checks `Account.all.any?` and runs seeds if no accounts exist. Three seed accounts are created:

1. **cleanslate** — Empty template (account + owner only)
2. **37signals** — Small demo (4 users, 1 board, 3 cards)
3. **honcho** — Full test data (6 users, 5 boards, 50 cards)

All seeds use `david@example.com` as the original owner identity (marked `staff: true`). The `create_tenant` function uses `ActiveRecord::FixtureSet.identify` for deterministic external IDs.

For production accounts created via signup, `Account::Seeder#populate` creates a "Playground" board with 9 onboarding cards.

---

## 8. Account Creation for Authenticated Users (Single-Tenant)

### The completions controller has no tenant gate

`Signups::CompletionsController` uses `disallow_account_scope` but does NOT check `accepting_signups?`. The `enforce_tenant_limit` check only exists in `SignupsController`, and authenticated users bypass it entirely — `redirect_authenticated_user` fires first and sends them straight to `/signup/completion/new`.

This means any authenticated identity can create accounts in single-tenant mode if they can reach the completions page.

### The signup route

The route is singular: `/signup/completion/new` (not `/signups/completions/new`). Defined at `config/routes.rb:161-167`. Routes are unconditional — no tenant-mode constraints.

### Completions controller context

`Signups::CompletionsController` has `disallow_account_scope`, so:
- `Current.account` is nil
- `Current.user` is nil (user resolution depends on account)
- Only `Current.identity` is available

This means role-based checks (owner/admin/member) are impossible in this controller. Roles are per-User, per-Account — an identity could be an owner in one account and a member in another. Any gating here must be identity-level.

### Cancellable approach (minimal change)

Instead of a new concern or env var, `cancellable?` can be extended to allow cancellation when the identity has other accounts to fall back to:

```ruby
def cancellable?
  Account.accepting_signups? || Current.identity&.accounts&.active&.many?
end
```

This enables the cancel button for owners with 2+ active accounts, without touching `accepting_signups?`.

### Account creation link placement

The jump menu (`my/menus/show.html.erb`) has these sections: Boards, Tags, People, Settings, Shortcuts, Accounts. The Accounts section (`_accounts.html.erb`) only renders when `accounts.many?`, so single-account users never see it.

Options for a "Create new account" link:
- **Accounts section** — relax the `accounts.many?` guard so it always renders; add a link. Most natural location, but shows a section with one link for single-account users
- **Settings section** (`_settings.html.erb`) — always visible, easy discovery. Semantically less fitting
- **Account settings page** (`account/settings/show.html.erb`) — pairs with cancellation (create/delete symmetry), but deeper in the UI

The jump menu renders within account scope, so `Current.user` is available. The link can be soft-gated with a role check:

```erb
<% if Current.user.admin? %>
  <%= filter_place_menu_item new_signup_path, "Create a new account", "plus" %>
<% end %>
```

This hides the link from members. Not a hard security boundary — someone who knows the URL can still reach `/signup/completion/new` — but sufficient for self-hosted use where you control the user base.

### Session menu limitation

The session menu (`sessions/menus/show.html.erb`) always shows "Sign up for a new Fizzy account" unconditionally. This page uses `disallow_account_scope`, so `Current.user` is nil and role-based hiding is impossible. Any authenticated identity with 2+ accounts will see this page and the link.

### Infinite account creation after invite

Once an identity is authenticated (via join code invite), they can create unlimited accounts through `/signup/completion/new`. The trust boundary is the invite itself. For self-hosted personal use, this is acceptable.

For a locked-down business deployment, identity-level controls would be needed:
- **Account count cap** — `Current.identity.accounts.active.count < N` checked in completions controller. N could be an env var.
- **Identity-level flag** — a boolean like `can_create_accounts` on the Identity model, set during the invite flow based on the type of invitation.
- **Staff flag** — `Identity` already has `staff: true/false`, but this is purpose-built for 37signals internal use and shouldn't be overloaded.

### Jump menu cache note

Only `_accounts.html.erb` uses fragment caching (keyed on `[Current.identity, accounts, Current.account]`). The other menu partials (boards, tags, people, settings, shortcuts) do not cache fragments — they rely on the HTTP-level `fresh_when etag:` in `My::MenusController`. If the accounts partial is restructured to always render, the cache key and block placement need updating.

---

## 9. Analysis: Workspace Tasks

### Task 1: Enable multi-tenant mode via deploy.yml

**What it controls:** Setting `MULTI_TENANT: true` in `config/deploy.yml:34` enables `Account.accepting_signups?`, which:
- Allows new identity/account creation at `/signup/new`
- Shows the "Sign up" link on the login page
- Allows account cancellation
- Routes unknown emails through the real signup flow instead of a fake magic link

**What it doesn't control:** URL path tenancy, account slug middleware, join code flow, data isolation. These are always active.

**To enable:** Change `MULTI_TENANT: false` to `MULTI_TENANT: true` in `config/deploy.yml:34`. No code changes needed.

**Risk:** Existing single-tenant account data is unaffected. The account continues to work at its existing slug. New accounts would get new slugs. The transition is additive.

### Task 2: Add signup restriction mode

**Current state:** The binary `accepting_signups?` doesn't distinguish between "allow signups" and "allow joins." When signups are blocked (`MULTI_TENANT: false`), the join code flow still works because `JoinCodesController` doesn't check `accepting_signups?`. This is good — it means invite-only access already works in single-tenant mode.

**Gap:** If `MULTI_TENANT` is set to `true` (for the URL tenancy benefits or to allow new accounts), there's no way to restrict *general* signups while still allowing joins. The `accepting_signups?` predicate is all-or-nothing.

**Evaluated approach — `SingleTenantable` concern with `ALLOW_ACCOUNTS_WHEN_SINGLE_TENANT` env var:** This was prototyped and found to work. A parallel concern alongside `MultiTenantable` would add `allow_single_tenant_accounts?`, gating the menus controller auto-redirect and cancellations. However, this adds a new concern, initializer, and env var for something achievable with smaller changes.

**Simpler approach — minimal changes, no new config:** Keep `accepting_signups?` untouched. Instead:
- Change `cancellable?` to: `Account.accepting_signups? || Current.identity&.accounts&.active&.many?` — allows cancellation when identity has fallback accounts
- Add a "Create new account" link to an accessible location (jump menu accounts section or settings section), soft-gated behind `Current.user.admin?`
- The completions controller already allows authenticated users to create accounts regardless of tenant mode — no changes needed there

**Trade-off:** This approach doesn't introduce new configuration. The invite (join code) is the trust boundary. Any authenticated identity can create accounts. For personal self-hosted use, this is acceptable. For locked-down business use, identity-level controls would be needed (see Section 8).

### Task 3: Make signup restriction configurable

**Current UI touchpoints:**

- `sessions/new.html.erb:13` — Conditionally shows signup link based on `accepting_signups?`
- `sessions/menus/show.html.erb:28` — Always shows "Sign up for a new account" link (not gated, no account scope available for role checks)
- `signups_controller.rb:28` — `enforce_tenant_limit` redirects based on `accepting_signups?`
- `my/menus/_accounts.html.erb:1` — Only renders when `accounts.many?`
- `my/menus/_settings.html.erb` — Always renders, has account scope for role checks
- `account/settings/_cancellation.html.erb:1` — Gated on `cancellable? && owner?`

**For personal self-hosted (minimal approach):**

No new configuration needed. The `accepting_signups?` flag stays false, blocking public signups. Authenticated users get access to account creation via a link in the jump menu. The session menu's signup link is an accepted gap — it only shows when an identity already has 2+ accounts.

**For business self-hosted (future, identity-level approach):**

Would require:
- An identity-level attribute (e.g., `can_create_accounts` boolean on Identity)
- A hard check in `Signups::CompletionsController` rejecting identities without the attribute
- Invite flow logic to set the attribute based on invitation type
- Conditional rendering in `sessions/menus/show.html.erb` based on `Current.identity.can_create_accounts?`

This is a separate effort from the current workspace scope.

---

## 9. Key Files Reference

| Area | File | Purpose |
|---|---|---|
| Config | `config/deploy.yml:34` | `MULTI_TENANT` env var |
| Config | `config/initializers/multi_tenant.rb` | Sets `Account.multi_tenant` from env/config |
| Model | `app/models/account/multi_tenantable.rb` | `accepting_signups?` predicate |
| Model | `app/models/account/cancellable.rb` | Gates cancellation on `accepting_signups?` |
| Model | `app/models/account.rb` | `create_with_owner`, slug encoding |
| Model | `app/models/current.rb` | Request-scoped context resolution |
| Model | `app/models/identity/joinable.rb` | `join` method for account membership |
| Model | `app/models/account/join_code.rb` | Join code redemption |
| Model | `app/models/signup.rb` | Signup validation and identity creation |
| Middleware | `config/initializers/tenanting/account_slug.rb` | URL path extraction |
| Middleware | `config/initializers/tenanting/turbo.rb` | Turbo Streams tenant scoping |
| Controller | `app/controllers/signups_controller.rb` | Signup flow, `enforce_tenant_limit` |
| Controller | `app/controllers/signups/completions_controller.rb` | Account creation |
| Controller | `app/controllers/sessions_controller.rb` | Login, signup routing |
| Controller | `app/controllers/join_codes_controller.rb` | Join code redemption |
| Controller | `app/controllers/sessions/menus_controller.rb` | Account selection |
| View | `app/views/sessions/new.html.erb` | Login page with conditional signup link |
| View | `app/views/sessions/menus/show.html.erb` | Account picker with signup link |
| Test | `test/models/account/multi_tenantable_test.rb` | Tests for `accepting_signups?` |
| Test | `test/controllers/signups_controller_test.rb` | Signup flow tests |
| Test | `test/test_helpers/session_test_helper.rb` | `with_multi_tenant_mode` helper |
