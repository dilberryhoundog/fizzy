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

## Tasks

1. **Enable multi-tenant mode via deploy.yml** — Investigate the single-tenant vs multi-tenant deploy setting, document what it controls, and switch the deployed app to multi-tenant.
2. **Add signup restriction mode** — Prevent general user signups for self-hosted private usage while preserving the account invite flow.
3. **Make signup restriction configurable** — Provide a choice to enable/disable general signups, either on the account selection screen (for the original user) or via deploy.yml.
4. **Change current account slug** - The users current account slug is 000000001 (not sure if it's a valid slug), this is easily guessable and should be changed to a more secure and random value, like when an account is created in the dev server.

## Constraints

- Integrate with existing systems to minimize upstream breaking changes
- Preserve the account invite flow (join codes, magic links)
- Ensure a fresh deploy still creates an original user when signups are restricted
- Maintain the current single-tenant account and its data when transitioning to multi-tenant

## Discoveries

- When renaming files. Use the mv command with relative file paths. don't cd to the directory first.
