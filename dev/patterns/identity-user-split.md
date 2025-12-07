# Identity/User Split Pattern

## Overview

This pattern separates **authentication** (who you are globally) from **authorization** (what you can do in a specific account). A single person can belong to multiple accounts with different roles, names, and permissions in each.

**Problem it solves:** In multi-tenant applications, users often need to:
- Access multiple organizations with one login
- Have different roles/permissions per organization
- Maintain separate profiles (name, avatar) per organization
- Be deactivated from one organization without losing access to others

**Core insight:** Authentication is global; authorization is contextual.

## Key Files

| File                                            | Purpose                                       |
|-------------------------------------------------|-----------------------------------------------|
| `app/models/identity.rb`                        | Global person (email-based authentication)    |
| `app/models/identity/joinable.rb`               | Logic for joining accounts                    |
| `app/models/identity/transferable.rb`           | Session transfer between devices              |
| `app/models/user.rb`                            | Account membership (per-tenant authorization) |
| `app/models/user/role.rb`                       | Role-based permissions                        |
| `app/models/user/accessor.rb`                   | Board-level access management                 |
| `app/models/account.rb`                         | The tenant (organization)                     |
| `app/models/session.rb`                         | Authentication session (belongs to Identity)  |
| `app/models/access.rb`                          | Resource-level permissions (User → Board)     |
| `app/models/current.rb`                         | Request-scoped context resolution             |
| `app/controllers/concerns/authentication.rb`    | Session management                            |
| `app/controllers/concerns/authorization.rb`     | Access control checks                         |
| `config/initializers/tenanting/account_slug.rb` | URL-based tenant extraction                   |

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     GLOBAL (no account_id)                      │
├─────────────────────────────────────────────────────────────────┤
│  Identity          Session           MagicLink                  │
│  - email_address   - identity_id     - identity_id              │
│  - staff           - user_agent      - code                     │
│  - avatar          - ip_address      - expires_at               │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ identity.users
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    TENANTED (has account_id)                    │
├─────────────────────────────────────────────────────────────────┤
│  Account ──────────────────────────────────────────────────┐    │
│  - name                                                    │    │
│  - external_account_id                                     │    │
│                                                            │    │
│  User (the membership) ◄───────────────────────────────────┘    │
│  - account_id                                                   │
│  - identity_id (nullable - nil when deactivated)                │
│  - role (owner/admin/member/system)                             │
│  - name (can differ from identity)                              │
│  - active                                                       │
│                                                                 │
│  Access (resource-level permission)                             │
│  - user_id                                                      │
│  - board_id                                                     │
│  - involvement (access_only/watching)                           │
└─────────────────────────────────────────────────────────────────┘
```

### Relationship Diagram

```
Identity (alice@example.com)
    │
    ├── Session (browser cookie)
    │
    ├── User in "Acme Corp" ────► Access to Board A (watching)
    │   - role: owner            Access to Board B (access_only)
    │   - name: "Alice Smith"
    │
    └── User in "Beta Inc" ─────► Access to Board X (watching)
        - role: member
        - name: "A. Smith"
```

## Implementation

### Identity Model

The global person, identified by email. Owns authentication artifacts (sessions, magic links) but delegates authorization to User records.

```ruby
# app/models/identity.rb
class Identity < ApplicationRecord
  include Joinable, Transferable

  has_many :magic_links, dependent: :destroy
  has_many :sessions, dependent: :destroy
  has_many :users, dependent: :nullify  # nullify, not destroy
  has_many :accounts, through: :users

  has_one_attached :avatar

  before_destroy :deactivate_users

  normalizes :email_address, with: ->(value) { value.strip.downcase.presence }

  def send_magic_link(**attributes)
    attributes[:purpose] = attributes.delete(:for) if attributes.key?(:for)

    magic_links.create!(attributes).tap do |magic_link|
      MagicLinkMailer.sign_in_instructions(magic_link).deliver_later
    end
  end

  private
    def deactivate_users
      users.find_each(&:deactivate)
    end
end
```

**Key design decisions:**
- `dependent: :nullify` on users — deactivating an identity doesn't delete user records, preserving audit trails
- Avatar on identity is the global default; users can have per-account avatars
- `staff` flag for internal employees (used for staging/beta access)

### Identity::Joinable Concern

Handles the logic of an identity joining an account, creating the User membership.

```ruby
# app/models/identity/joinable.rb
module Identity::Joinable
  extend ActiveSupport::Concern

  def join(account, **attributes)
    attributes[:name] ||= email_address

    transaction do
      account.users.find_or_create_by!(identity: self) do |user|
        user.assign_attributes(attributes)
      end.previously_new_record?
    end
  end
end
```

**Key design decisions:**
- Idempotent — calling `join` twice returns the existing user
- Returns boolean indicating if a new user was created (`previously_new_record?`)
- Default name falls back to email address
- Transaction ensures atomicity

### User Model

The account membership. This is where per-account customization lives.

```ruby
# app/models/user.rb
class User < ApplicationRecord
  include Accessor, Assignee, Attachable, Configurable, EmailAddressChangeable,
    Mentionable, Named, Notifiable, Role, Searcher, Watcher
  include Timelined # Depends on Accessor

  has_one_attached :avatar do |attachable|
    attachable.variant :thumb, resize_to_fill: [ 256, 256 ]
  end

  belongs_to :account
  belongs_to :identity, optional: true  # nil when deactivated

  has_many :comments, inverse_of: :creator, dependent: :destroy
  has_many :filters, foreign_key: :creator_id, inverse_of: :creator, dependent: :destroy
  has_many :closures, dependent: :nullify
  has_many :pins, dependent: :destroy
  has_many :pinned_cards, through: :pins, source: :card
  has_many :exports, class_name: "Account::Export", dependent: :destroy

  scope :with_avatars, -> { preload(:account, :avatar_attachment) }

  def deactivate
    transaction do
      accesses.destroy_all
      update! active: false, identity: nil
      close_remote_connections
    end
  end

  def setup?
    name != identity.email_address
  end

  private
    def close_remote_connections
      ActionCable.server.remote_connections.where(current_user: self).disconnect(reconnect: false)
    end
end
```

**Key design decisions:**
- `identity: optional` — allows "zombie" users (deactivated but preserved for history)
- `active` flag for soft-delete
- `deactivate` severs the identity link, removes board access, disconnects websockets
- `setup?` checks if user has customized their profile beyond default email

### User::Role Concern

Defines the role hierarchy and permission checks.

```ruby
# app/models/user/role.rb
module User::Role
  extend ActiveSupport::Concern

  included do
    enum :role, %i[ owner admin member system ].index_by(&:itself), scopes: false

    scope :owner, -> { where(active: true, role: :owner) }
    scope :admin, -> { where(active: true, role: %i[ owner admin ]) }
    scope :member, -> { where(active: true, role: :member) }
    scope :active, -> { where(active: true, role: %i[ owner admin member ]) }

    # Override enum's admin? to include owners
    def admin?
      super || owner?
    end
  end

  def can_change?(other)
    (admin? && !other.owner?) || other == self
  end

  def can_administer?(other)
    admin? && !other.owner? && other != self
  end

  def can_administer_board?(board)
    admin? || board.creator == self
  end

  def can_administer_card?(card)
    admin? || card.creator == self
  end
end
```

**Role hierarchy:**
- `owner` — Top level, cannot be demoted by others
- `admin` — Can manage users (except owners), `admin?` returns true
- `member` — Regular user
- `system` — Internal account for system-generated content

**Key design decisions:**
- `scopes: false` on enum prevents auto-generated scopes (custom ones are more useful)
- Custom scopes combine `active` check with role check
- `admin?` override makes owners implicitly admins
- Permission methods check both role AND ownership (creator gets admin rights on their resources)

### User::Accessor Concern

Manages board-level access for users.

```ruby
# app/models/user/accessor.rb
module User::Accessor
  extend ActiveSupport::Concern

  included do
    has_many :accesses, dependent: :destroy
    has_many :boards, through: :accesses
    has_many :accessible_cards, through: :boards, source: :cards
    has_many :accessible_comments, through: :accessible_cards, source: :comments

    after_create_commit :grant_access_to_boards, unless: :system?
  end

  private
    def grant_access_to_boards
      Access.insert_all account.boards.all_access.pluck(:id).collect { |board_id|
        { id: ActiveRecord::Type::Uuid.generate, board_id: board_id, user_id: id, account_id: account.id }
      }
    end
end
```

**Key design decisions:**
- New users automatically get access to all `all_access` boards
- System users don't get board access (they're internal)
- `insert_all` for performance (no callbacks, single query)

### Access Model

The join table between User and Board with involvement level.

```ruby
# app/models/access.rb
class Access < ApplicationRecord
  belongs_to :account, default: -> { user.account }
  belongs_to :board, touch: true
  belongs_to :user, touch: true

  enum :involvement, %i[ access_only watching ].index_by(&:itself), default: :access_only

  scope :ordered_by_recently_accessed, -> { order(accessed_at: :desc) }

  after_destroy_commit :clean_inaccessible_data_later

  def accessed
    touch :accessed_at unless recently_accessed?
  end

  private
    def recently_accessed?
      accessed_at&.> 5.minutes.ago
    end

    def clean_inaccessible_data_later
      Board::CleanInaccessibleDataJob.perform_later(user, board)
    end
end
```

**Involvement levels:**
- `access_only` — Can view the board
- `watching` — Gets notified of all board activity

**Key design decisions:**
- `touch: true` on associations for cache invalidation
- `accessed_at` tracking with debounce (5 min) for "recently viewed" features
- Cleanup job removes orphaned mentions/notifications when access revoked

### Account Model

The tenant. Contains factory method for creating accounts with owners.

```ruby
# app/models/account.rb
class Account < ApplicationRecord
  include Entropic, Seedeable

  has_one :join_code
  has_many :users, dependent: :destroy
  has_many :boards, dependent: :destroy
  has_many :cards, dependent: :destroy
  has_many :webhooks, dependent: :destroy
  has_many :tags, dependent: :destroy
  has_many :columns, dependent: :destroy
  has_many :exports, class_name: "Account::Export", dependent: :destroy

  has_many_attached :uploads

  before_create :assign_external_account_id
  after_create :create_join_code

  validates :name, presence: true

  class << self
    def create_with_owner(account:, owner:)
      create!(**account).tap do |account|
        account.users.create!(role: :system, name: "System")
        account.users.create!(**owner.reverse_merge(role: "owner"))
      end
    end
  end

  def slug
    "/#{AccountSlug.encode(external_account_id)}"
  end

  def account
    self
  end

  def system_user
    users.where(role: :system).first!
  end

  private
    def assign_external_account_id
      self.external_account_id ||= ExternalIdSequence.next
    end
end
```

**Key design decisions:**
- `create_with_owner` factory ensures every account has a system user and an owner
- `external_account_id` is the URL-visible identifier (separate from internal UUID)
- `system_user` for automated actions (system comments, etc.)
- `account` method returns self (allows `record.account` to work on Account itself)

### Session Model

Minimal — just links to Identity. Authentication state lives in signed cookies.

```ruby
# app/models/session.rb
class Session < ApplicationRecord
  belongs_to :identity
end
```

### Current Context

The magic that resolves Identity + Account → User automatically.

```ruby
# app/models/current.rb
class Current < ActiveSupport::CurrentAttributes
  attribute :session, :user, :account
  attribute :http_method, :request_id, :user_agent, :ip_address, :referrer

  delegate :identity, to: :session, allow_nil: true

  def session=(value)
    super(value)

    if value.present? && account.present?
      self.user = identity.users.find_by(account: account)
    end
  end

  def with_account(value, &block)
    with(account: value, &block)
  end

  def without_account(&block)
    with(account: nil, &block)
  end
end
```

**The key insight:** When `session` is set (from cookie), if we already know the `account` (from URL), we can automatically resolve which User record applies.

### Account Slug Middleware

Extracts account from URL path, sets `Current.account` for the entire request.

```ruby
# config/initializers/tenanting/account_slug.rb
module AccountSlug
  PATTERN = /(\d{7,})/
  FORMAT = "%07d"
  PATH_INFO_MATCH = /\A(\/#{AccountSlug::PATTERN})/

  class Extractor
    def initialize(app)
      @app = app
    end

    def call(env)
      request = ActionDispatch::Request.new(env)

      if request.script_name && request.script_name =~ PATH_INFO_MATCH
        env["fizzy.external_account_id"] = AccountSlug.decode($2)
      elsif request.path_info =~ PATH_INFO_MATCH
        request.engine_script_name = request.script_name = $1
        request.path_info = $'.empty? ? "/" : $'
        env["fizzy.external_account_id"] = AccountSlug.decode($2)
      end

      if env["fizzy.external_account_id"]
        account = Account.find_by(external_account_id: env["fizzy.external_account_id"])
        Current.with_account(account) do
          @app.call env
        end
      else
        Current.without_account do
          @app.call env
        end
      end
    end
  end

  def self.decode(slug) slug.to_i end
  def self.encode(id) FORMAT % id end
end

Rails.application.config.middleware.insert_after Rack::TempfileReaper, AccountSlug::Extractor
```

**URL structure:** `/{account_id}/boards/...` where account_id is a 7+ digit number.

**Key design decisions:**
- Moves account prefix from `PATH_INFO` to `SCRIPT_NAME` (Rails thinks app is "mounted" at that path)
- All URL helpers automatically include the account prefix
- Requests without account prefix run with `Current.account = nil`

### Authentication Concern

Manages session lifecycle and authentication requirements.

```ruby
# app/controllers/concerns/authentication.rb
module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_account
    before_action :require_authentication
    after_action :ensure_development_magic_link_not_leaked
    helper_method :authenticated?

    etag { Current.session.id if authenticated? }

    include LoginHelper
  end

  class_methods do
    def require_unauthenticated_access(**options)
      allow_unauthenticated_access **options
      before_action :redirect_authenticated_user, **options
    end

    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
      before_action :resume_session, **options
      allow_unauthorized_access **options
    end

    def disallow_account_scope(**options)
      skip_before_action :require_account, **options
      before_action :redirect_tenanted_request, **options
    end
  end

  private
    def authenticated?
      Current.session.present?
    end

    def require_account
      unless Current.account.present?
        redirect_to session_menu_url(script_name: nil)
      end
    end

    def require_authentication
      resume_session || request_authentication
    end

    def resume_session
      if session = find_session_by_cookie
        set_current_session session
      end
    end

    def find_session_by_cookie
      Session.find_signed(cookies.signed[:session_token])
    end

    def request_authentication
      if Current.account.present?
        session[:return_to_after_authenticating] = request.url
      end
      redirect_to_login_url
    end

    def after_authentication_url
      session.delete(:return_to_after_authenticating) || landing_url
    end

    def redirect_authenticated_user
      redirect_to root_url if authenticated?
    end

    def redirect_tenanted_request
      redirect_to root_url if Current.account.present?
    end

    def start_new_session_for(identity)
      identity.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
        set_current_session session
      end
    end

    def set_current_session(session)
      Current.session = session
      cookies.signed.permanent[:session_token] = { value: session.signed_id, httponly: true, same_site: :lax }
    end

    def terminate_session
      Current.session.destroy
      cookies.delete(:session_token)
    end
end
```

**Controller macros:**
- `allow_unauthenticated_access` — Skip auth requirement (login pages, public pages)
- `require_unauthenticated_access` — Must NOT be logged in (redirects if authenticated)
- `disallow_account_scope` — Page works without account context (account selector, etc.)

### Authorization Concern

Ensures the authenticated identity has a User in the current account.

```ruby
# app/controllers/concerns/authorization.rb
module Authorization
  extend ActiveSupport::Concern

  included do
    before_action :ensure_can_access_account, if: -> { Current.account.present? && authenticated? }
    before_action :ensure_only_staff_can_access_non_production_remote_environments, if: :authenticated?
  end

  class_methods do
    def allow_unauthorized_access(**options)
      skip_before_action :ensure_can_access_account, **options
    end

    def require_access_without_a_user(**options)
      skip_before_action :ensure_can_access_account, **options
      before_action :redirect_existing_user, **options
    end
  end

  private
    def ensure_admin
      head :forbidden unless Current.user.admin?
    end

    def ensure_staff
      head :forbidden unless Current.identity.staff?
    end

    def ensure_can_access_account
      redirect_to session_menu_url(script_name: nil) if Current.user.blank? || !Current.user.active?
    end

    def ensure_only_staff_can_access_non_production_remote_environments
      head :forbidden unless Rails.env.local? || Rails.env.production? || Current.identity.staff?
    end

    def redirect_existing_user
      redirect_to root_path if Current.user
    end
end
```

**Key checks:**
- `ensure_can_access_account` — Identity must have an active User in this account
- `ensure_admin` — User must be admin/owner
- `ensure_staff` — Identity must be internal staff (for staging access)

## Database Schema

```ruby
# identities - Global, no account_id
create_table "identities", id: :uuid do |t|
  t.string "email_address", null: false
  t.boolean "staff", default: false, null: false
  t.timestamps
  t.index ["email_address"], unique: true
end

# sessions - Global, belongs to identity
create_table "sessions", id: :uuid do |t|
  t.uuid "identity_id", null: false
  t.string "ip_address"
  t.string "user_agent", limit: 4096
  t.timestamps
  t.index ["identity_id"]
end

# accounts - The tenant
create_table "accounts", id: :uuid do |t|
  t.string "name", null: false
  t.bigint "external_account_id"
  t.timestamps
  t.index ["external_account_id"], unique: true
end

# users - The membership (identity + account)
create_table "users", id: :uuid do |t|
  t.uuid "account_id", null: false
  t.uuid "identity_id"  # nullable for deactivated users
  t.string "name", null: false
  t.string "role", default: "member", null: false
  t.boolean "active", default: true, null: false
  t.timestamps
  t.index ["account_id", "identity_id"], unique: true
  t.index ["account_id", "role"]
  t.index ["identity_id"]
end

# accesses - Resource-level permissions
create_table "accesses", id: :uuid do |t|
  t.uuid "account_id", null: false
  t.uuid "user_id", null: false
  t.uuid "board_id", null: false
  t.string "involvement", default: "access_only", null: false
  t.datetime "accessed_at"
  t.timestamps
  t.index ["board_id", "user_id"], unique: true
end
```

## Usage Examples

### Creating an Account with Owner

```ruby
account = Account.create_with_owner(
  account: { name: "Acme Corp" },
  owner: { name: "Alice Smith", identity: identity }
)
# Creates: Account, system User, owner User
```

### Joining an Account via Join Code

```ruby
# In JoinCodesController#create
identity = Identity.find_or_create_by!(email_address: params[:email_address])
join_code.redeem_if { |account| identity.join(account) }
```

### Checking Permissions

```ruby
# In a controller
def destroy
  head :forbidden unless Current.user.can_administer_board?(@board)
  @board.destroy
end

# Role checks
Current.user.admin?        # true for admin OR owner
Current.user.owner?        # true only for owner
Current.user.can_change?(other_user)  # can edit their profile?
```

### Accessing Resources Through User

```ruby
# Get all boards user can access
Current.user.boards

# Get all cards user can access
Current.user.accessible_cards

# Check if user can access specific board
board.accessible_to?(Current.user)
```

### Deactivating a User

```ruby
user.deactivate
# - Removes all board accesses
# - Sets active: false
# - Sets identity: nil (severs link)
# - Disconnects ActionCable
```

### Context Resolution Flow

```
1. Request: GET /1234567/boards
2. Middleware extracts account_id → Current.account = Account.find_by(external_account_id: 1234567)
3. Controller resumes session → Current.session = Session.find_signed(cookie)
4. Current.session= setter runs → Current.user = identity.users.find_by(account: Current.account)
5. Authorization checks → ensure Current.user.present? && Current.user.active?
```

## Adaptation Notes

### Minimum Viable Implementation

For simpler apps, you can skip:
- `Access` model (if all users see all resources)
- `involvement` enum (if no "watching" concept)
- `system` role (if no automated actions)
- `Transferable` concern (if no device transfer feature)

### Alternative Tenant Resolution

Instead of URL path (`/account_id/...`), you could use:
- Subdomain: `acme.app.com` → resolve via `request.subdomain`
- Header: `X-Account-ID` → for API-only apps
- Session: Store selected account in session → for single-domain apps

### Role Customization

The role hierarchy is easily extensible:

```ruby
enum :role, %i[ owner admin manager member viewer system ].index_by(&:itself)

def manager?
  super || admin?
end
```

### Without Board-Level Access

If you don't need resource-level permissions:

```ruby
class User < ApplicationRecord
  # Remove Accessor concern
  # Remove Access model
  # Authorization is purely role-based
end
```

### activerecord-tenanted Compatibility

This pattern is designed to work with the `activerecord-tenanted` gem when it ships:

- `Identity`, `Session`, `MagicLink` would stay on the global/untenanted database
- Everything with `account_id` would become tenanted (separate DB per account)
- The `Current` context and middleware patterns remain unchanged
- The gem handles connection switching; your code stays the same
