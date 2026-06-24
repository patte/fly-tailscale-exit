#!/usr/bin/env sh
# Template for staging the Tailscale auth credential as a Fly secret.
# Copy this to env.sh (gitignored), fill in your value, then run it.
#
# The official image's containerboot authenticates with TS_AUTHKEY. Use either:
#  - an OAuth client secret (tskey-client-…) for an OAuth client tagged
#    tag:fly-exit (recommended), or
#  - a reusable, ephemeral, pre-approved auth key (tskey-…)

fly secrets set TS_AUTHKEY=<your tskey-client-… or tskey-… value>
