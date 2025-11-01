# Workflow Configuration

Default configuration templates for Claude Code and GitHub workflows. This repository serves as a starting point for new projects, providing pre-configured commands, agents, skills, and templates.

## Contents

### `.claude-user/`
User-specific Claude Code configuration that applies globally across all projects:

- **commands/** - Custom slash commands for common tasks
  - `commit.md` - Well-formatted commits with conventional commit messages
  - `commit-staged.md` - Commit staged files
  - `edit-md.md` - Edit markdown files with embedded comments
  - `new-branch.md` - Create new git branches
  - `web-search.md` - Search websites for information

- **agents/** - Specialized AI agents for specific tasks
  - `css-class-finder.md` - Find existing CSS classes for styling
  - `rails-log-analyzer.md` - Analyze Rails error logs

- **skills/** - Reusable skill modules
  - `git/` - Git operations (branch, commit, pull, push)
  - `skill-creator/` - Tools for creating new skills
  - `test/` - Test skill for experimentation

- **output-styles/** - Different output formatting styles
  - `concise.md` - Brief, to-the-point responses
  - `managed.md` - Structured task management
  - `rails_backend.md` - Rails backend development style
  - `rails_frontend.md` - Rails frontend development style
  - `show-working.md` - Show detailed work process
  - `solid-code.md` - Emphasis on solid code principles

### `.claude/`
Project-specific Claude Code configuration:

- **commands/** - Project-level slash commands
  - `CSS/` - CSS-related commands (component imports, context)
  - `github/` - GitHub workflow commands (issues, PRs)
  - `cleanup.md` - Code cleanup tasks
  - `create_docs.md` - Documentation generation
  - `html_scratchpad.md` - HTML experimentation
  - `record_feature.md` - Feature documentation
  - `ruby_scratchpad.md` - Ruby experimentation

- **agents/** - Project-specific agents
  - `css-support.md` - CSS development assistance
  - `index-file-auditor.md` - Audit index files

- **output-styles/** - Project output styles
  - `rails-progressive.md` - Progressive Rails development
  - `rails-simple.md` - Simple Rails development

### `.github/`
GitHub repository templates:

- **ISSUE_TEMPLATE/** - Issue templates for different scenarios
  - `bug-report.yml` - Bug reports
  - `claude-task.yml` - Claude Code tasks
  - `feature-request.yml` - Feature requests
  - `github-workflow.yml` - Workflow improvements
  - `quick-capture.yml` - Quick issue capture
  - `refactor-chore.yml` - Refactoring and chores

- **workflows/** - GitHub Actions
  - `claude-code-review.yml` - Automated code review workflow

- `pull_request_template.md` - Pull request template

### `dev/`
Development documentation and setup instructions.

## Usage

### For New Projects

1. Copy the desired configuration directories to your new project:
   ```bash
   # Copy user configuration (optional, if not already in ~/.claude/)
   cp -r .claude-user/ ~/your-project/

   # Copy project configuration
   cp -r .claude/ ~/your-project/

   # Copy GitHub templates
   cp -r .github/ ~/your-project/
   ```

2. Customize the configuration files for your project's specific needs.

3. Commit the configuration to your project repository.

### For Global Configuration

Copy the `.claude-user/` contents to your global Claude configuration directory:
```bash
cp -r .claude-user/* ~/.claude/
```

## Customization

All configuration files are markdown-based and can be easily edited to suit your workflow:

- **Commands** - Add new slash commands by creating `.md` files in the `commands/` directory
- **Agents** - Define specialized agents in the `agents/` directory
- **Skills** - Create reusable skill modules in the `skills/` directory
- **Output Styles** - Customize how Claude responds in different contexts

## Contributing

Feel free to submit pull requests with improvements to the default configurations or new templates that would be useful across projects.

## License

This configuration repository is intended for personal/team use. Modify as needed for your workflow.
