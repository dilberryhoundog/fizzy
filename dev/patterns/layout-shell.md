# Minimal Shell Layout Pattern

## Overview

This pattern structures Rails layouts as minimal shells that provide semantic zones and injection points, while delegating width constraints and content structure to individual pages. Instead of creating multiple layout variants (`narrow.html.erb`, `wide.html.erb`, `centered.html.erb`), pages control their own presentation via CSS classes.

**Problem it solves:** Traditional Rails apps often accumulate layout variants as different pages need different widths or structures. This leads to:
- Layout proliferation and maintenance burden
- Duplication of shared elements (head, flash, footer)
- Awkward decisions about which layout a page should use
- Difficulty when a page needs a mix of widths (narrow header, wide content)

**Core insight:** Layouts should define *where* content goes, not *how wide* it should be. Width is a styling concern that belongs in CSS, controlled by the page via class names.

## Key Files

| File | Purpose |
|------|---------|
| `app/views/layouts/application.html.erb` | Main layout shell |
| `app/views/layouts/public.html.erb` | Stripped-down layout for unauthenticated pages |
| `app/views/layouts/shared/_head.html.erb` | Document head with injection point |
| `app/views/layouts/shared/_flash.html.erb` | Flash messages with Turbo Frame |
| `app/views/layouts/shared/_user_css.html.erb` | Dynamic user-scoped CSS |
| `app/views/layouts/shared/_time_zone.html.erb` | Auto timezone sync |
| `app/assets/stylesheets/layout.css` | Grid-based body layout |
| `app/assets/stylesheets/panels.css` | Width constraint classes |
| `app/helpers/application_helper.rb` | `page_title_tag` helper |

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│ application.html.erb                                              │
├──────────────────────────────────────────────────────────────────┤
│  <head>                                                           │
│    └── _head.html.erb                                             │
│          ├── meta tags, CSP, CSRF                                 │
│          ├── stylesheets, importmaps                              │
│          ├── _user_css.html.erb (dynamic)                         │
│          └── yield :head ◄─────── page injects meta/social tags   │
│                                                                   │
│  <body>                                                           │
│    ├── <header class="header @header_class">                      │
│    │     ├── _menu.html.erb (if authenticated)                    │
│    │     └── yield :header ◄───── page injects title/actions      │
│    │                                                              │
│    ├── _flash.html.erb                                            │
│    ├── _time_zone.html.erb (if authenticated)                     │
│    │                                                              │
│    ├── <main id="main">                                           │
│    │     └── yield ◄───────────── page content (owns its width)   │
│    │                                                              │
│    └── <footer id="footer">                                       │
│          ├── yield :footer ◄───── page injects footer content     │
│          └── persistent frames (bar, trays) with turbo-permanent  │
└──────────────────────────────────────────────────────────────────┘
```

### Injection Mechanisms

**Instance variables** (for simple values):
- `@page_title` → Used by `page_title_tag` helper in `<title>`
- `@header_class` → Applied to `<header class="header <%= @header_class %>">`
- `@hide_footer_frames` → Conditionally hides persistent footer UI
- `@disable_view_transition` → Disables view transitions for specific pages

**Named yields** (for content blocks):
- `yield :head` → Page-specific `<meta>` tags, Open Graph, social cards
- `yield :header` → Page-specific header content (back link, title, actions)
- `yield :footer` → Page-specific footer content
- `yield` → Main content

## Implementation

### The Shell Layout

```erb
<!-- app/views/layouts/application.html.erb -->
<!DOCTYPE html>
<html lang="en">
  <%= render "layouts/shared/head" %>

  <body data-controller="local-time timezone-cookie turbo-navigation">
    <header class="header <%= @header_class %>" id="header">
      <a href="#main" class="header__skip-navigation btn">Skip to main content</a>
      <%= render "my/menu" if Current.user %>
      <%= yield :header %>
    </header>

    <%= render "layouts/shared/flash" %>
    <%= render "layouts/shared/time_zone" if Current.user %>

    <main id="main">
      <%= yield %>
    </main>

    <footer id="footer">
      <%= yield :footer %>

      <% if Current.user && !@hide_footer_frames %>
        <div id="footer_frames" data-turbo-permanent="true">
          <%= render "bar/bar" %>
          <%= render "my/pins/tray" %>
          <%= render "notifications/tray" %>
        </div>
      <% end %>
    </footer>
  </body>
</html>
```

**Key design decisions:**
- Grid-based body layout (see CSS below) creates predictable zones
- `data-turbo-permanent` on footer frames keeps them across navigation
- Skip navigation link for accessibility
- Conditional rendering based on `Current.user` and flags

### The Head Partial

```erb
<!-- app/views/layouts/shared/_head.html.erb -->
<head>
  <%= page_title_tag %>

  <meta name="viewport" content="width=device-width, initial-scale=1">
  <% unless @disable_view_transition %>
    <meta name="view-transition" content="same-origin">
  <% end %>
  <meta name="color-scheme" content="light dark">
  <%= csrf_meta_tags %>
  <%= csp_meta_tag %>
  <%= tag.meta name: "current-user-id", content: Current.user.id if Current.user %>

  <% turbo_refreshes_with method: :morph, scroll: :preserve %>

  <%= stylesheet_link_tag :app, "data-turbo-track": "reload" %>
  <%= javascript_importmap_tags %>

  <%= tenanted_action_cable_meta_tag %>
  <%= render "layouts/shared/user_css" %>

  <%= yield :head %>

  <link rel="manifest" href="<%= pwa_manifest_path(format: :json) %>">
  <link rel="icon" href="/favicon.png" type="image/png">
</head>
```

**Notable methods:**
- `page_title_tag` — Helper that builds title from `@page_title`
- `turbo_refreshes_with` — Rails 8 Turbo morphing
- `tenanted_action_cable_meta_tag` — Multi-tenant WebSocket URL

### Page Title Helper

```ruby
# app/helpers/application_helper.rb
module ApplicationHelper
  def page_title_tag
    account_name = if Current.account && Current.session&.identity&.users&.many?
      Current.account&.name
    end
    tag.title [ @page_title, account_name, "Fizzy" ].compact.join(" | ")
  end
end
```

Builds title like: "Card Title | Acme Corp | Fizzy" (account name only shows if user has multiple accounts).

### CSS Layout Foundation

```css
/* app/assets/stylesheets/layout.css */
@layer base {
  body {
    display: grid;
    grid-template-rows: auto 1fr auto 9em; /* header, main, footer, bar space */

    &.public {
      grid-template-rows: auto 1fr auto; /* no bar space for public pages */
    }
  }

  :where(#main) {
    inline-size: 100dvw;
    margin-inline: auto;
    max-inline-size: 100dvw;
    padding-inline:
      calc(var(--main-padding) + env(safe-area-inset-left))
      calc(var(--main-padding) + env(safe-area-inset-right));
    text-align: center; /* centers inline-block children */
  }
}
```

**Key insight:** `#main` is full-width with responsive padding. It doesn't constrain content width—pages do that themselves.

### Width Control Classes {#widths}

```css
/* app/assets/stylesheets/panels.css */
@layer components {
  .panel {
    background-color: var(--panel-bg, var(--color-canvas));
    border: var(--panel-border-size, 1px) solid var(--panel-border-color, var(--color-ink-lighter));
    border-radius: var(--panel-border-radius, 1em);
    inline-size: var(--panel-size, 60ch);
    max-inline-size: 100%;
    padding: var(--panel-padding, var(--block-space));

    @media (min-width: 640px) {
      --panel-size: 100%;
      padding: var(--panel-padding, var(--block-space-double));
    }
  }

  .panel--wide {
    --panel-size: 60ch;
  }

  .panel--centered {
    --panel-border-size: 0;
    --panel-size: 100%;

    @media (min-width: 640px) {
      --panel-size: 42ch;
    }

    /* The magic: child affects parent layout */
    #main:has(&) {
      display: grid;
      justify-content: center;
      margin: auto;
    }
  }
}
```

**The `:has()` trick:** When a page uses `.panel--centered`, CSS automatically modifies `#main` to center its content. No JavaScript, no layout variant needed.

### User-Scoped CSS {#user-css}

```erb
<!-- app/views/layouts/shared/_user_css.html.erb -->
<% if Current.user %>
  <style>
    [data-creator-id="<%= Current.user.id %>"] {
      [data-only-visible-to-others] { display: none; }
    }
    [data-creator-id]:not([data-creator-id="<%= Current.user.id %>"]) {
      [data-only-visible-to-you] { display: none; }
    }
  </style>
<% end %>
```

This enables "Only visible to you" / "Only visible to others" badges without JavaScript:

```erb
<!-- In a card partial -->
<div data-creator-id="<%= card.creator_id %>">
  <span data-only-visible-to-you>Draft - only you can see this</span>
  <span data-only-visible-to-others>Shared with you</span>
</div>
```

### Flash Messages with Animation Cleanup

```erb
<!-- app/views/layouts/shared/_flash.html.erb -->
<%= turbo_frame_tag :flash do %>
  <% if notice = flash[:notice] || flash[:alert] %>
    <div class="flash" data-controller="element-removal" data-action="animationend->element-removal#remove">
      <div class="flash__inner shadow">
        <%= notice %>
      </div>
    </div>
  <% end %>
<% end %>
```

Uses CSS `animationend` event to trigger removal—no timers needed. The Turbo Frame allows flash updates via streams.

### Auto Timezone Sync

```erb
<!-- app/views/layouts/shared/_time_zone.html.erb -->
<% if timezone_from_cookie.present? && timezone_from_cookie != Current.user.timezone %>
  <%= auto_submit_form_with url: my_timezone_path, method: :put do %>
    <%= hidden_field_tag :timezone_name, timezone_from_cookie.name %>
  <% end %>
<% end %>
```

If browser timezone (set by Stimulus controller via cookie) differs from saved preference, auto-submits to update it. Silent UX fix on page load.

## Usage Examples

### Narrow Centered Form (Login) {#injection}

```erb
<!-- app/views/sessions/new.html.erb -->
<% @page_title = "Enter your email" %>

<div class="panel panel--centered flex flex-column gap-half">
  <h1>Get into Fizzy</h1>
  <%= form_with url: session_path do |form| %>
    <%= form.email_field :email_address, required: true %>
    <button type="submit">Let's go</button>
  <% end %>
</div>

<% content_for :footer do %>
  <%= render "sessions/footer" %>
<% end %>
```

### Page with Header Actions

```erb
<!-- app/views/boards/show.html.erb -->
<% @page_title = @board.name %>

<% content_for :header do %>
  <div class="header__actions header__actions--start">
    <%= link_to_webhooks(@board) if Current.user.admin? %>
  </div>

  <h1 class="header__title">
    <%= @board.name %>
  </h1>

  <div class="header__actions header__actions--end">
    <%= link_to_edit_board @board %>
  </div>
<% end %>

<%= render "boards/show/columns", board: @board %>
```

### Card with Custom Header Class and Meta Tags

```erb
<!-- app/views/cards/show.html.erb -->
<% @page_title = @card.title %>
<% @header_class = "header--card" %>

<% content_for :head do %>
  <%= card_social_tags(@card) %>
<% end %>

<% content_for :header do %>
  <div class="header__actions header__actions--start">
    <%= link_back_to_board(@card.board) %>
  </div>
<% end %>

<%= render "cards/container", card: @card %>
```

### Medium Width Settings Panels

```erb
<!-- app/views/account/settings/show.html.erb -->
<% @page_title = "Account Settings" %>

<% content_for :header do %>
  <h1 class="header__title"><%= @page_title %></h1>
<% end %>

<section class="settings margin-block-start-half">
  <div class="settings__panel panel shadow center">
    <%= render "account/settings/name", account: @account %>
  </div>

  <div class="settings__panel panel shadow center">
    <%= render "account/settings/users", users: @users %>
  </div>
</section>
```

## Multiple Layouts

Fizzy has a few layout variants for genuinely different contexts:

### Public Layout (Unauthenticated)

```erb
<!-- app/views/layouts/public.html.erb -->
<!DOCTYPE html>
<html lang="en">
  <%= render "layouts/shared/head" %>

  <body class="public" data-controller="local-time timezone-cookie">
    <header class="header" id="header">
      <nav>
        <%= link_to "https://fizzy.do" do %>
          <%= image_tag "logo.png" %>
        <% end %>
      </nav>
      <%= yield :header %>
    </header>

    <main id="main">
      <%= yield %>
    </main>

    <footer id="footer">
      <%= yield :footer %>
    </footer>
  </body>
</html>
```

Simpler header (logo link instead of menu), no persistent footer frames, `body.public` triggers different grid layout.

### Mailer Layout

```erb
<!-- app/views/layouts/mailer.html.erb -->
<!DOCTYPE html>
<html>
  <head>
    <style>
      /* Inline email-safe CSS */
    </style>
  </head>
  <body>
    <table id="body">
      <%= yield %>
    </table>
  </body>
</html>
```

Table-based for email client compatibility, inline styles.

## Adaptation Notes

### Minimum Viable Implementation

For simpler apps:

```erb
<!-- layouts/application.html.erb -->
<!DOCTYPE html>
<html>
  <head>
    <title><%= [@page_title, "MyApp"].compact.join(" | ") %></title>
    <%= csrf_meta_tags %>
    <%= stylesheet_link_tag :app %>
    <%= javascript_importmap_tags %>
    <%= yield :head %>
  </head>
  <body class="<%= @body_class %>">
    <header>
      <%= render "shared/nav" if Current.user %>
      <%= yield :header %>
    </header>

    <%= render "shared/flash" %>

    <main>
      <%= yield %>
    </main>

    <footer>
      <%= yield :footer %>
    </footer>
  </body>
</html>
```

### Without `:has()` (Older Browser Support)

If you can't use `:has()`, use explicit body classes:

```erb
<body class="<%= 'body--centered' if @centered_layout %>">
```

```css
.body--centered #main {
  display: grid;
  justify-content: center;
}
```

### Admin vs. User Layouts

Instead of separate admin layout, use the same shell with conditional rendering:

```erb
<header class="header <%= 'header--admin' if Current.user&.admin? %>">
  <%= render Current.user&.admin? ? "admin/nav" : "nav" %>
  <%= yield :header %>
</header>
```

### Adding More Injection Points

If you need more slots, just add them:

```erb
<!-- In layout -->
<aside id="sidebar">
  <%= yield :sidebar %>
</aside>

<!-- In page -->
<% content_for :sidebar do %>
  <%= render "filters/panel" %>
<% end %>
```

### Turbo Permanent Elements

For UI that should persist across navigation (notifications, chat, media player):

```erb
<div id="persistent_ui" data-turbo-permanent>
  <%= render "notifications/badge" %>
  <%= render "audio/player" %>
</div>
```

These elements survive Turbo navigations—their state (scroll position, form values, JS state) is preserved.