#!/usr/bin/env sh
# Smoke-test a built image without a tailnet: run it with no auth key, so
# tailscaled stays in NeedsLogin and the healthz CGI must report 503. Asserting
# that proves start.sh runs, httpd serves /cgi-bin/healthz, and the CGI executes
# — the full wiring, with no secrets needed.
#
# Usage: scripts/smoke-test.sh <image>
set -eu

IMAGE="${1:?usage: scripts/smoke-test.sh <image>}"
NAME="fly-ts-smoke-$$"

cleanup() { docker rm -f "$NAME" >/dev/null 2>&1 || true; }
trap cleanup EXIT

docker run -d --name "$NAME" -p 9002:9002 -e FLY_REGION=ci \
  --cap-add=NET_ADMIN --device /dev/net/tun "$IMAGE" >/dev/null

code=""
i=0
while [ "$i" -lt 30 ]; do
  code=$(curl -s -o /dev/null -w '%{http_code}' http://localhost:9002/cgi-bin/healthz 2>/dev/null || true)
  [ "$code" = "503" ] && break
  i=$((i + 1))
  sleep 1
done

echo "healthz returned: ${code:-<none>} (expected 503)"
if [ "$code" != "503" ]; then
  echo "smoke test FAILED: start.sh/httpd/healthz did not serve 503"
  docker logs "$NAME" || true
  exit 1
fi
echo "smoke test passed: start.sh + httpd + healthz CGI are wired correctly"
