# Repository Secret Setup Required

## CLAUDE_CODE_OAUTH_TOKEN Configuration

**MANUAL STEP REQUIRED**: The CLAUDE_CODE_OAUTH_TOKEN must be added as a repository secret.

### Steps to Add the Secret:

1. Go to your repository on GitHub
2. Navigate to Settings → Secrets and variables → Actions
3. Click "New repository secret"
4. Add the following secret:
   - **Name**: `CLAUDE_CODE_OAUTH_TOKEN`
   - **Value**: (Obtain from Anthropic Claude Code setup)

### Why This Is Required:

The CLAUDE_CODE_OAUTH_TOKEN is essential because:
- GITHUB_TOKEN cannot trigger workflows (GitHub security limitation)
- This token allows repository_dispatch events from within Claude action context
- Without it, parent agents cannot spawn child agents

### Verification:

After adding the secret, verify it's available by checking:
- Repository Settings → Secrets → Repository secrets
- Should show CLAUDE_CODE_OAUTH_TOKEN (hidden value)

**Note**: This is a one-time manual setup that cannot be automated for security reasons.