# State Management Guide

Agents maintain persistent state across sessions using markdown files.

## How It Works

1. **State files** live in `[project]/.claude/state/[agent].md`
2. **At session start**, agent reads its state file
3. **At session end**, agent updates the state file
4. **Next session** picks up where the last one left off

## State File Template

```markdown
# [Agent Name] State - [Project Name]

## Last Updated
2026-01-26 18:00 UTC

## Current Focus
Primary objective or sprint goal

## Active Work
| Task | Status | Notes |
|------|--------|-------|
| Implement auth | In Progress | OAuth flow done |
| Fix mobile bug | Blocked | Waiting on design |

## Blockers
- [ ] Need design specs for settings page
- [x] ~~API rate limiting~~ (resolved)

## Recent Decisions
- 2026-01-25: Chose PostgreSQL over MongoDB for ACID compliance
- 2026-01-24: Decided to use Tailwind for styling

## Context for Next Session
Currently working on the authentication flow. OAuth is complete,
need to implement session management next. The session table
migration is in `migrations/004_sessions.sql` but not yet applied.
```

## Agent-Specific State

### Engineering (`eng.md`)
Additional sections:
- **Current Sprint Goal** - What's the focus this sprint
- **Technical Debt Queue** - Tracked debt items with priority

### Product (`product.md`)
Additional sections:
- **Backlog (Prioritized)** - Features ranked by value/effort
- **User Insights Queue** - Feedback patterns to act on

### Design (`design.md`)
Additional sections:
- **Design System Status** - Component completion tracking
- **Accessibility Checklist** - WCAG compliance items

### Marketing (`marketing.md`)
Additional sections:
- **Active Campaigns** - Running campaigns with results
- **Growth Experiments** - Hypothesis, status, outcome

### Sales (`sales.md`)
Additional sections:
- **Pipeline Overview** - Deal counts by stage
- **Active Deals** - Specific deals with next actions

### Content (`content.md`)
Additional sections:
- **Content Calendar** - Planned content by week
- **Performance Tracking** - Published content metrics

## Portfolio State (Multi-Product)

For founders with multiple products, create:

**`~/business/.claude/state/portfolio.md`**

```markdown
# Portfolio Overview

## Last Updated
2026-01-26 18:00 UTC

## Active Products

### Product A - SaaS Tool
- **Stage**: Growth
- **Health**: 🟢
- **This Week**: Launch v2.0
- **Founder Time**: 60%

### Product B - Mobile App
- **Stage**: Pre-launch
- **Health**: 🟡
- **This Week**: Beta testing
- **Founder Time**: 30%

## Cross-Project Considerations
- Shared auth system between A and B
- Content can be repurposed across both

## This Week's Allocation
| Day | Product A | Product B | Admin |
|-----|-----------|-----------|-------|
| Mon | 4h | 2h | 1h |
| Tue | 3h | 4h | 0h |
```

## Initializing State

Run the init script for new projects:

```bash
~/.claude/plugins/solo-founder-fleet/scripts/init-project-state.sh /path/to/project
```

Creates all 7 state files with default templates.

## Best Practices

1. **Be specific in "Context for Next Session"** - Include file paths, variable names, specific decisions
2. **Update state frequently** - Don't wait until session end if making significant progress
3. **Track blockers immediately** - Add them as soon as discovered
4. **Document decisions with dates** - Creates an audit trail
5. **Keep Active Work table current** - Remove completed items, add new ones
