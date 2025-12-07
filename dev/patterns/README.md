# Rails Pattern Extractions

Detailed pattern documentation extracted from the Fizzy codebase. Each file contains:

1. **Overview** - What the pattern does and why
2. **Key Files** - Source files to reference
3. **Implementation** - Complete code with annotations
4. **Usage Examples** - How the pattern is used in Fizzy
5. **Adaptation Notes** - How to modify for your own apps

## Extracted Patterns
- [activerecord-tenanted.md](activerecord-tenanted.md)
- [identity-user-split.md](identity-user-split.md)
- [layout-shell.md](layout-shell.md)

## Pattern Categories

### Authentication & Sessions
- `magic-link-auth.md` - Passwordless authentication with timed codes
- `sessions.md` - Database-backed session management
- `identity-user-split.md` - Multi-account identity architecture ✓

### Multi-Tenancy
- `url-path-tenancy.md` - Path-based tenant isolation via middleware
- `current-attributes.md` - Request-scoped context with CurrentAttributes
- `job-context.md` - Serializing tenant context in background jobs

### Controller Patterns
- `auth-concern.md` - Flexible authentication concern with macros
- `authorization.md` - Role-based authorization
- `resource-scoping.md` - DRY nested resource loading
- `etag-caching.md` - Personalized HTTP caching

### Model Patterns
- `eventable.md` - Polymorphic audit trail
- `searchable.md` - Full-text search integration
- `notifiable.md` - Notification dispatch on model changes
- `broadcastable.md` - Real-time UI updates via ActionCable
- `mentions.md` - @mention parsing and notifications
- `taggable.md` - Dynamic tagging system
- `assignable.md` - User assignment with tracking
- `closeable.md` - Status lifecycle management
- `watchable.md` - Subscription/watch functionality

### View & Frontend
- `layout-shell.md` - Minimal shell layout with injection points, CSS-driven widths ✓
- `turbo-frames.md` - Isolated page regions
- `turbo-streams.md` - Broadcast-driven updates
- `stimulus-patterns.md` - Common Stimulus controller patterns
- `partials.md` - Partial organization and naming

### Background Jobs
- `solid-queue.md` - Database-backed job queue setup
- `notification-bundling.md` - Email aggregation over time windows
- `recurring-jobs.md` - Scheduled task configuration

### Rich Text & Attachments
- `action-text.md` - Rich text editor setup
- `storage-variants.md` - Image variant configuration

### Webhooks & Integrations
- `webhooks.md` - Webhook delivery with state machine
- `push-notifications.md` - Web push via VAPID

### Infrastructure
- `uuid-keys.md` - UUIDv7 primary keys
- `sharded-search.md` - Multi-shard full-text search
- `rails-extensions.md` - Framework customizations

### Domain-Specific
- `entropy.md` - Auto-postponement system
- `publication.md` - Public sharing with tokens
- `card-lifecycle.md` - Draft/published/closed states
- `filters.md` - Composable query scopes

---

## Quick Start

1. Browse patterns in `CLAUDE.md` (root) for quick reference
2. Read detailed file here when implementing
3. Check `Key Files` section for original source code

## Contributing

When extracting new patterns:
- Include complete, working code (not snippets)
- Explain the "why" not just the "how"
- Note any dependencies or prerequisites
- Add adaptation guidance for different contexts
