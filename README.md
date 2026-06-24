fly-tailscale-exit — official image
-----------------------------------

A [Tailscale](https://tailscale.com) exit node on [Fly.io](https://fly.io) using the **official `tailscale/tailscale` image**.

This is an alternative to the [`main`](https://github.com/patte/fly-tailscale-exit) branch, which builds a custom Alpine image around raw `tailscaled`. Here we let Tailscale's own [containerboot](https://tailscale.com/kb/1282/docker) do the work and only fill the one gap it leaves on Fly.

Features:
- [x] Tailscale exit node from the official `tailscale/tailscale` image, driven entirely by `TS_*` env vars
- [x] the whole setup is a single `fly.toml` — no Dockerfile, no scripts to maintain
- [x] auth with an OAuth client secret (or auth key) via `TS_AUTHKEY`
- [x] kernel networking (`TS_USERSPACE=false`); tailscaled sets up its own NAT
- [x] IP forwarding enabled via a one-line `[experimental] cmd` override (the only thing containerboot won't do on Fly)
- [x] per-region hostname `fly-<region>`
- [x] native health endpoint (`TS_ENABLE_HEALTH_CHECK`) wired to a Fly `[checks]` block

## Quickstart

Assumes the [`fly` CLI](https://fly.io/docs/hands-on/installing/) and a Tailscale tailnet with public DNS + a `tag:fly-exit` in your ACLs. (Full account/ACL/DNS walkthrough is in the [main README](https://github.com/patte/fly-tailscale-exit/blob/main/README.md#setup).)

```bash
git clone -b official-image https://github.com/patte/fly-tailscale-exit.git
cd fly-tailscale-exit

fly launch                          # copy the bundled fly.toml, pick a name, don't deploy yet

# OAuth client secret (recommended) or an auth key, as TS_AUTHKEY:
fly secrets set TS_AUTHKEY=tskey-client-…

fly deploy --ha=false
```

Then approve the `fly-<region>` node as an exit node in the [admin](https://login.tailscale.com/admin/machines) (and sign it if you use tailnet lock), and route through it:

```bash
tailscale set --exit-node=fly-<region>
```

## How it works

`containerboot` (the image's entrypoint) reads `TS_*` env vars, starts `tailscaled`, runs `tailscale up`, and even serves `/healthz`. On Fly it handles almost everything an exit node needs — auth, exit-node advertisement, and the NAT/masquerade rules — **except enabling IP forwarding**, which Fly's microVM kernel leaves off (`net.ipv4.ip_forward=0`). Without it the node registers as an exit node but silently routes nothing:

```
Warning: IP forwarding is disabled, subnet routing/exit nodes will not work.
```

So the trick is a one-line command override that enables forwarding, sets a per-region hostname, then hands off to the original entrypoint:

```toml
[experimental]
  cmd = ["/bin/sh", "-c", "echo 1 > /proc/sys/net/ipv4/ip_forward; echo 1 > /proc/sys/net/ipv6/conf/all/forwarding; export TS_HOSTNAME=fly-$FLY_REGION; exec /usr/local/bin/containerboot"]
```

That's it. Verified end-to-end: a client routed through the node egresses from the Fly region (an `nrt` deploy exits with a Tokyo IP).

## vs. the custom-image approach (main)

| | this branch (official image) | [main](https://github.com/patte/fly-tailscale-exit) (custom image) |
|---|---|---|
| build | none — `tailscale/tailscale:latest` | custom Alpine Dockerfile + `tailscaled` download |
| start logic | containerboot (`TS_*` env) | `start.sh` |
| auth | `TS_AUTHKEY` (OAuth secret or key) | OAuth token exchange in `start.sh`, or key |
| ip_forward | `[experimental] cmd` one-liner | `sysctl` in `start.sh` |
| NAT | tailscaled's own rules | manual `MASQUERADE` |
| health | native `TS_ENABLE_HEALTH_CHECK` | custom `healthz` CGI + busybox `httpd` |
| updates | bump the `tailscale/tailscale` tag | weekly Action bumps `TSVERSION`, gated on CI |

Trade-off: this branch is far less to maintain, but `main` shows the mechanics ("tailscale as if on a real Linux host") and pins/auto-updates a specific tailscale version with a tested CI. Pick whichever fits.

## The `connmark` warning in `fly logs`

You'll still see this — it's harmless and **not** specific to either approach:

```
- enabling connmark rules: … iptables … Extension CONNMARK revision 0 not supported, missing kernel module?
```

tailscaled wants to install a `CONNMARK` rule for fwmark-based policy routing, but Fly's microVM kernel doesn't ship the `xt_CONNMARK` module. Exit routing still works because tailscaled's masquerade + connection tracking handle the return path. (The official image hits this too, despite using `iptables-legacy` — it's a Fly-kernel limitation.)
