# Ruby-LLM Activity Summaries (Removed)

> **Status:** Removed in commit `aa1ffb3` - "Remove AI summaries and semantic searches"
> **Reason:** "We were not using either. We can restore if we revisit."

## Overview

Fizzy had AI-powered weekly activity summaries using the `ruby-llm` gem with OpenAI. The system generated "news style" summaries of board activity with headlines and blurbs, helping users spot patterns and milestones they might miss scanning individual events.

## Components

### 1. Event Summarizer
- **File:** `app/models/event/summarizer.rb`
- Took a collection of events, sent to LLM with domain-aware prompts
- Generated markdown with headlines (h3 lead, h4 sub-stories)
- Included injection attack prevention in system prompt
- Used `gpt-5-chat-latest` model, 125k token limit

### 2. AI Cost Tracking
- **File:** `app/models/ai/cost.rb`
- Calculated token costs in microcents using `RubyLLM.models` pricing
- Tracked input/output tokens separately
- Used `Ai::Cost::Money` wrapper for currency handling

### 3. User Summaries
- **File:** `app/models/user/summaries.rb`
- Weekly summary generation per user
- Period-based caching to avoid regenerating
- Background job: `User::Summaries::GenerateAllJob`

### 4. Semantic Search (Embeddings)
- **File:** `app/models/search/embedding.rb`
- Vector embeddings for cards/comments
- Refresh job: `Search::RefreshEmbeddingJob`

### 5. Admin Prompt Sandbox
- **File:** `app/controllers/admin/prompt_sandboxes_controller.rb`
- UI for testing/iterating on prompts

## Key Patterns Worth Extracting

1. **Domain-aware LLM prompts** - Explaining your data model to the LLM
2. **Injection prevention** - System prompt hardening for user content
3. **Cost tracking** - Token metering for LLM usage
4. **Period-based caching** - Avoiding duplicate generation

## Discovery Prompts

- How did they structure the event-to-prompt conversion?
- What was the full domain model prompt?
- How did semantic search integrate with existing full-text?
- What VCR testing patterns did they use for LLM calls?

## Git Archaeology

```bash
# View the summarizer before removal
git show aa1ffb3^:app/models/event/summarizer.rb

# View cost tracking
git show aa1ffb3^:app/models/ai/cost.rb

# View ruby_llm config
git show aa1ffb3^:config/initializers/ruby_llm.rb

# List all removed AI files
git show aa1ffb3 --name-only | grep -E "ai/|summar|embed"
```