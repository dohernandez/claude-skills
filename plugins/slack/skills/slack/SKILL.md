---
name: slack
description: "Access Slack workspace for reading messages and posting notifications. Use when user says /slack."
user-invocable: true
allowed-tools:
  - Read
  - Bash
  - WebFetch
hooks:
  Stop:
    - type: command
      command: "task -t .claude/Taskfile.yaml validate-skill -- --skill slack"
---

# Slack

## Purpose

Provide Slack access for reading messages and posting notifications. Supports two access methods: MCP server (recommended) or direct API via bot token.

## Quick Reference

### Method 1: MCP Server (Recommended)

If a Slack MCP server is configured, use it directly - no setup required.

### Method 2: Bot Token + API

```bash
# Check if Slack env vars are configured
grep -E '^SLACK_(BOT_TOKEN|CHANNEL_ID)=' .env

# Fetch recent messages
source .env
curl -s -H "Authorization: Bearer $SLACK_BOT_TOKEN" \
  "https://slack.com/api/conversations.history?channel=$SLACK_CHANNEL_ID&limit=10" \
  | jq '.messages[] | {ts: .ts, text: .text}'
```

## Access Methods

### MCP Server (Recommended)

If a Slack MCP server is available, it handles authentication and provides tools like:
- `slack_list_channels` - List available channels
- `slack_read_messages` - Read messages from a channel
- `slack_post_message` - Post a message to a channel
- `slack_search` - Search messages

Check MCP server availability before falling back to direct API.

### Direct API via Bot Token

For projects without MCP, use Slack's REST API with a bot token.

#### Prerequisites

Add to `.env` file:

```bash
# Slack Bot Token (xoxb-...)
# Get from: Slack App > OAuth & Permissions > Bot User OAuth Token
SLACK_BOT_TOKEN=xoxb-your-token-here

# Default Channel ID
# Get from: Right-click channel > View channel details > Copy ID (at bottom)
SLACK_CHANNEL_ID=C0XXXXXXXX

# Optional: Additional channels
SLACK_ALERTS_CHANNEL_ID=C0XXXXXXXX
SLACK_NOTIFICATIONS_CHANNEL_ID=C0XXXXXXXX
```

#### Bot Token Scopes

The Slack bot needs these OAuth scopes:
- `channels:history` - Read messages from public channels
- `channels:read` - View basic channel info
- `chat:write` - Post messages
- `files:write` - Upload files (optional)

## Reading Messages

### Via MCP (if available)

```
Use slack_read_messages tool with channel parameter
```

### Via API

```bash
source .env

# Fetch recent messages
curl -s -H "Authorization: Bearer $SLACK_BOT_TOKEN" \
  "https://slack.com/api/conversations.history?channel=$SLACK_CHANNEL_ID&limit=10" \
  | jq -r '.messages[] | "\(.ts): \(.text)"'

# Fetch messages in time range (Unix timestamps)
OLDEST=$(date -u -v-1H "+%s")  # 1 hour ago (macOS)
curl -s -H "Authorization: Bearer $SLACK_BOT_TOKEN" \
  "https://slack.com/api/conversations.history?channel=$SLACK_CHANNEL_ID&oldest=$OLDEST" \
  | jq '.messages[]'
```

### Manual (Fallback)

1. Open Slack desktop or web app
2. Navigate to the target channel
3. Copy the message text
4. Provide to Claude for analysis

## Posting Messages

### Via MCP (if available)

```
Use slack_post_message tool with channel and text parameters
```

### Via API

```bash
source .env

# Post simple message
curl -s -X POST -H "Authorization: Bearer $SLACK_BOT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "channel": "'"$SLACK_CHANNEL_ID"'",
    "text": "Hello from the bot!",
    "unfurl_links": false
  }' \
  "https://slack.com/api/chat.postMessage"

# Post with formatting (Blocks)
curl -s -X POST -H "Authorization: Bearer $SLACK_BOT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "channel": "'"$SLACK_CHANNEL_ID"'",
    "blocks": [
      {
        "type": "header",
        "text": {"type": "plain_text", "text": "Status Update"}
      },
      {
        "type": "section",
        "text": {"type": "mrkdwn", "text": "*Service:* my-service\n*Status:* Healthy"}
      }
    ]
  }' \
  "https://slack.com/api/chat.postMessage"
```

## Message Format

Common alert/notification format:

```
[SEVERITY] service-name - Message
Time: timestamp
```

**Severity levels:**
- `[ERROR]` - Requires immediate attention
- `[WARN]` - Potential issue, monitor
- `[INFO]` - Informational, no action needed

## Verifying Access

### Check MCP Availability

Look for Slack-related MCP tools in the available tools list.

### Check Bot Token

```bash
# Verify env vars exist
grep -E '^SLACK_' .env

# Test authentication
source .env
curl -s -H "Authorization: Bearer $SLACK_BOT_TOKEN" \
  "https://slack.com/api/auth.test" | jq '.ok, .user, .team'

# Test channel access
curl -s -H "Authorization: Bearer $SLACK_BOT_TOKEN" \
  "https://slack.com/api/conversations.history?channel=$SLACK_CHANNEL_ID&limit=1" \
  | jq '.ok'
```

## Common Issues

| Issue | Solution |
|-------|----------|
| `invalid_auth` | Check SLACK_BOT_TOKEN is correct and not expired |
| `channel_not_found` | Use channel ID (C0XXX), not channel name |
| `not_in_channel` | Add bot to channel: `/invite @BotName` |
| `missing_scope` | Add required OAuth scopes and reinstall app |

## Configuration

### Config Location

Config path depends on how the plugin was installed:

| Plugin Scope | Config File | Git |
|--------------|-------------|-----|
| **project** | `.claude/skills/slack.yaml` | Committed (shared) |
| **local** | `.claude/skills/slack.local.yaml` | Ignored (personal) |
| **user** | `.claude/skills/slack.local.yaml` | Ignored (personal) |

**Precedence when reading** (first found wins):
1. `.claude/skills/slack.local.yaml`
2. `.claude/skills/slack.yaml`
3. Skill defaults

## Reference

- [Slack API Documentation](https://api.slack.com/methods)
- [Slack Block Kit Builder](https://app.slack.com/block-kit-builder)
- [Creating a Slack App](https://api.slack.com/start)