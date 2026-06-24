#!/usr/bin/env sh
# Template for staging Tailscale credentials as Fly secrets.
# Copy this to env.sh (gitignored), fill in your real values, then run it.
# Use ONE authentication method (see README step 5):

# Option A — OAuth client (recommended, README step 5B):
fly secrets set TAILSCALE_OAUTH_CLIENT_ID=<your-oauth-client-id> TAILSCALE_OAUTH_SECRET=<your-oauth-client-secret>

# Option B — Auth key (README step 5A):
# fly secrets set TAILSCALE_AUTH_KEY=<your-auth-key>
