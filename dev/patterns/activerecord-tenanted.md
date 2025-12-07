# ActiveRecord-Tenanted / Per-Tenant SQLite (Removed)

> **Status:** Removed in PR #1558 "Plan B" - "Fizzy on MySQL"
> **Key Commits:** `4d3c26504` (rip out), `6705b5225` (remove untenanted db)
> **Reason:** Switched to shared MySQL for UUID compatibility between SAAS/self-hosted and better search

## Overview

Fizzy originally used `activerecord-tenanted` gem (private 37signals gem) to give each account its own SQLite database file. This provided complete tenant isolation at the database level. "Plan B" replaced this with a shared MySQL database using `account_id` columns and sharded search tables.

## Architecture (Before Plan B)

```
storage/tenants/{env}/{account_id}/db/
├── main.sqlite3        # Tenant's primary database
├── main.sqlite3.1      # Rolling backup 1
├── main.sqlite3.2      # Rolling backup 2
└── ...
```

### Key Components

1. **ApplicationRecord Tenanting**
   ```ruby
   class ApplicationRecord < ActiveRecord::Base
     primary_abstract_class
     tenanted  # Magic method from activerecord-tenanted
   end
   ```

2. **Default Tenant Config**
   - Development defaulted to tenant `686465299` (Honcho)
   - Test environment set in test_helper.rb

3. **SQLite Backup Job**
   - Used SQLite Backup API for hot backups
   - Rolling file retention (keep N backups)
   - NFS sweep for disaster recovery
   - 30-day retention policy

4. **Tenant Iteration**
   ```ruby
   ApplicationRecord.with_each_tenant do |tenant|
     # Run across all tenant databases
   end
   ```

5. **Active Storage Integration**
   - Tenant-aware URL generation
   - Files organized by tenant directory

## Why Plan B?

1. **UUID Portability** - UUIDs enable data transfer between SAAS and self-hosted instances
2. **Search Consolidation** - MySQL full-text search across all tenants (16 shards by account CRC32)
3. **Operational Simplicity** - Single database easier to manage than thousands of SQLite files
4. **AI Search Deprecation** - Semantic/embedding search removed, standard full-text sufficient

## What Replaced It

- **URL path tenancy** - `/{account_id}/...` via middleware
- **Current.account** - Request-scoped tenant context
- **account_id columns** - Every table includes account reference
- **Sharded search** - 16 MySQL tables by `CRC32(account_id) % 16`

## Patterns Worth Extracting

1. **SQLite Backup API usage** - Hot backups without locking
2. **Rolling backup strategy** - File rotation with sweep
3. **Per-tenant file organization** - Directory structure
4. **Tenant iteration pattern** - `with_each_tenant` block

## Discovery Prompts

- How did `activerecord-tenanted` gem work internally?
- What was the migration path from SQLite-per-tenant to shared MySQL?
- How did they handle the data migration for existing tenants?
- What were the scaling issues that prompted Plan B?

## Git Archaeology

```bash
# View ApplicationRecord with tenanting
git show 4d3c26504^:app/models/application_record.rb

# View SQLite backup job (full implementation)
git show 4d3c26504^:app/jobs/sqlite_backups_job.rb

# View default tenant config
git show 4d3c26504^:config/initializers/tenanting/default_tenant.rb

# View Active Storage tenant integration
git show 4d3c26504^:config/initializers/tenanting/active_storage.rb

# View database.yml with tenant structure
git show 6705b5225^:config/database.yml

# See full Plan B merge diff
git show ed9be0674 --stat
```

## Related Links

- `activerecord-tenanted` gem: `github.com/basecamp/activerecord-tenanted` (private)
- SQLite Backup API: https://www.sqlite.org/c3ref/backup_finish.html