# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# Refactor Multi-Tenant Investigation

**Branch:** `refactor/multi-tenant-investigation`
**Started:** `2026-01-30`
**Status:**

- [x] In Progress
- [ ] Discard (workspace and branch abandoned)
- [ ] Complete (ready to merge)

## Purpose

Investigate and evaluate the current multi-tenancy implementation in Fizzy. Explore the URL path-based tenancy architecture (AccountSlug middleware, Current.account context, account_id scoping) and identify opportunities for refactoring to improve usability for self hosting.

## Discoveries

- When renaming files. Use the mv command with relative file paths. don't cd to the directory first.
