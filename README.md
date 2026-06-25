fly-tailscale-exit
------------------

![Action Status: auto update tailscale version](https://github.com/patte/fly-tailscale-exit/actions/workflows/auto-update-tailscale.yml/badge.svg)

This repo shows how to run tailscale on fly, specifically to run exit nodes.
If you want to add tailscale to a fly.io application, follow this guide instead: https://tailscale.com/kb/1132/flydotio/

Features:
- [x] runs a Tailscale exit node on Fly.io microVMs (real kernel networking, not a userspace proxy)
- [x] small docker image based on `alpine:3.23`, pulls a pinned `tailscale` release
- [x] auth via an OAuth client (mints a tagged, ephemeral, pre-approved key) or a plain auth key
- [x] advertises `--advertise-exit-node`, hostname `fly-<region>`
- [x] IPv4 + IPv6 forwarding and `MASQUERADE` NAT for egress
- [x] ephemeral, in-memory node state (`tailscaled --state=mem:`), auto-removed on shutdown
- [x] health endpoint: busybox `httpd` serves `/cgi-bin/healthz`, wired to a Fly `[checks]` block
  - returns `200` when the node is connected to the tailnet, `503` otherwise
- [x] self-healing: the container exits if `tailscaled` dies, so Fly restarts the machine
- [x] CI: `shellcheck`, `hadolint`, image build, and a no-secrets `healthz` smoke test
- [x] published to GHCR as a cosign-signed image (SLSA provenance + SBOM), so you can deploy without cloning
- [x] weekly GitHub Action to auto-update `tailscale`, gated on CI, opening an issue on failure
- [x] Dependabot for the base image and GitHub Actions

> [!WARNING]  
> In September 2023 [Tailscale](https://tailscale.com/blog/mullvad-integration) and [Mullvad](https://mullvad.net/en/blog/tailscale-has-partnered-with-mullvad) announced to partner up: for $5/month you can use a mullvad exit node from up to 5 tailscale nodes. This is great news and I'd recommend to use this instead of the setup described here. Follow [this guide](https://tailscale.com/kb/1258/mullvad-exit-nodes) to set it up.


## Quickstart

It assumes you have the [`fly` CLI](https://fly.io/docs/hands-on/installing/) installed and a Tailscale tailnet with public DNS configured. The full walkthrough (GitHub org, ACLs, `tag:fly-exit`, regions) is under [Setup](#setup) below.

```bash
git clone https://github.com/patte/fly-tailscale-exit.git
cd fly-tailscale-exit

fly launch                     # copy the bundled fly.toml, pick a name, don't deploy yet

# Tailscale credentials as Fly secrets
# OAuth client (https://login.tailscale.com/admin/settings/trust-credentials):
fly secrets set TAILSCALE_OAUTH_CLIENT_ID=<id> TAILSCALE_OAUTH_SECRET=<secret>
# or auth key (https://login.tailscale.com/admin/settings/keys):
# fly secrets set TAILSCALE_AUTH_KEY=<key>

fly deploy --ha=false          # a single machine
```

The node appears as `fly-<region>` in the [Tailscale admin](https://login.tailscale.com/admin/machines) — approve it as an exit node (and sign it if you use tailnet lock). Then route through it from any device:

```bash
tailscale set --exit-node=fly-<region>
```

Add more regions with `fly scale count 1 --region fra` (see step 13 below).

## Even quicker: deploy straight from the image (no clone)

Every change publishes a signed image to the GitHub Container Registry, so the fastest start is a few CLI commands — no clone, no Dockerfile, no `fly.toml`, no files at all:

```bash
fly apps create my-exit-node        # pick a unique name; creates no fly.toml
fly secrets set -a my-exit-node \
  TAILSCALE_OAUTH_CLIENT_ID=<id> TAILSCALE_OAUTH_SECRET=<secret>   # or TAILSCALE_AUTH_KEY=<key>
fly machine run ghcr.io/patte/fly-tailscale-exit:latest -a my-exit-node --region fra
```

Approve the `fly-<region>` node in the [admin console](https://login.tailscale.com/admin/machines), then activate the exit node (`tailscale set --exit-node=fly-<region>`). On most networks Tailscale hole-punches a **direct** connection through Fly's NAT; restrictive client NATs (hard CGNAT, some mobile hotspots) fall back to [DERP](https://tailscale.com/kb/1232/derp-servers) relays.

<details>
<summary>A managed app (fly.toml), image tags, and verifying the signature</summary>

**For a more advanced setup** — health checks and easy scaling across regions — use the [Quickstart](#quickstart) clone; uncomment the `image =` line in its [`fly.toml`](fly.toml) to deploy this prebuilt image instead of building.

**Tags** — `:latest` tracks the newest tailscale release; `:<tailscale-version>` (e.g. `:1.98.4`) pins one. The image is `linux/amd64`, rebuilt weekly for `alpine` base-image patches, and the 25 most recent versions are kept.

**Verify the signature** — the image is keyless-signed with [cosign](https://docs.sigstore.dev/) and carries SLSA provenance + an SBOM:

```bash
cosign verify ghcr.io/patte/fly-tailscale-exit:latest \
  --certificate-identity-regexp '^https://github.com/patte/fly-tailscale-exit/' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

</details>

## Alternative: the official Tailscale image

Prefer Tailscale's official `tailscale/tailscale` image over this custom build? There's a verified [`official-image`](https://github.com/patte/fly-tailscale-exit/tree/official-image) branch where the whole exit node is a single `fly.toml`. [containerboot](https://tailscale.com/kb/1282/docker) handles auth, exit-node advertisement, NAT, and a native `/healthz`; the only Fly-specific gap — enabling IP forwarding — is closed by a one-line `[experimental] cmd` override that runs before the entrypoint. Confirmed routing real exit traffic.

## Intro

Did you ever need a wormhole to another place in the internet? But you didn't trust the shady VPN providers with ads all over YouTube?
Well, why not run it "yourself"? This guide helps you to set up a globally distributed and easily sharable VPN service for you and your friends.
- Instantly scale up or down nodes around the planet
- Choose where your traffic exits to the internet from [30+ locations](https://fly.io/docs/reference/regions/).
- Enjoy solid connections worldwide
- ~~Bonus: the setup and the first 160GB of traffic each month are gratis.~~ _Update_: ~~a dedicated IPv4 to enable P2P communication (not via DERP) now costs $2/mo~~ — peer-to-peer actually works for free via Tailscale's [NAT traversal](https://tailscale.com/blog/how-nat-traversal-works/); no dedicated IPv4 is needed (verified — it goes unused). _Update 2_: Fly.io's free tier (160/140GB) isn't meant for use by proxies. Your fly plan might get [upgraded to a $10/month “Advanced” plan](https://community.fly.io/t/4896). Thanks [@ignoramous](https://github.com/patte/fly-tailscale-exit/issues/37) for the heads up.


Sounds too good to be true. Well that's probably because it is. I compiled this setup as an excercise while exploring the capabilities of fly.io and tailscale. This is probably not what you should use as a serious VPN replacement. Go to one of the few trustworthy providers. For the reasons why this is a bad idea, read [below](#user-content-why-this-probably-is-a-bad-idea).

Checkout gbraad's fork if you want to include squid, dante and gitpod https://github.com/spotsnel/tailscale-tailwings 

![Screenshot](https://user-images.githubusercontent.com/3500621/129452513-52133b60-02b8-4ec8-9605-0a6e3a089f9e.png)

<details>
<summary>Video of tailscale on iOS changing exit nodes.</summary>
<br>
https://user-images.githubusercontent.com/3500621/129452512-616e7642-5a03-4037-9dc1-f6be96ca1e30.mp4
</details>


## Setup

#### 1. Have a GitHub account
Create a GitHub account if you don't have one already: https://github.com/signup

#### 2. Have a GitHub organization
Let's create a new github org for your network: https://github.com/organizations/plan
- Choose a name for your network: eg. `banana-bender-net`
- Plan: free

#### 3. Have tailscale
Install tailscale on your machine(s):
- Install it on your notebook and mobile phone: https://tailscale.com/download
- Login with github, choose the github organization created before (eg. `banana-bender-net`).
- Check your network and keep this tab around: https://login.tailscale.com/admin/machines

#### 4. Setup DNS in tailscale
In order to use tailscale for exit traffic you need to configure a public DNS. Go to https://login.tailscale.com/admin/dns and add the nameservers of your choice (eg. cloudflare: `1.1.1.1, 1.0.0.1, 2606:4700:4700::1111, 2606:4700:4700::1001`)

#### 5. Authentication Options

You have two options for authenticating your Tailscale nodes:

##### Option A: Create a tailscale auth key (traditional method)
Create an auth key in tailscale: https://login.tailscale.com/admin/settings/authkeys

Choose the following options:
- `reusable` (for more than one device)
- `ephemeral` (autoremove if going offline)
- `pre-approved` (automatically approved)

##### Option B: Create an OAuth client (recommended)
1. Go to your Tailscale admin console: https://login.tailscale.com/admin/settings/oauth
2. Create a new OAuth client with the following scopes:
   - `devices:core:write`
   - `auth_keys:write`
3. Apply the tag `tag:fly-exit` to the OAuth client
4. Save the client ID and secret for use in step 9

Using OAuth is recommended as it provides more fine-grained access control and is the modern authentication method for Tailscale.

#### 6. Have a fly.io account and cli
Install the fly-cli to your machine and login with github: https://fly.io/docs/hands-on/installing/

#### 7. Have a fly.io organization
- Create an org on fly (technically there is no requirement to name it the same).
`fly orgs create banana-bender-net`
- Go and enter your credit card at [https://fly.io/organizations/banana-bender-net](https://fly.io/organizations). It's only going to be charged if you use more than the [free resources](https://fly.io/docs/about/pricing/).

#### 8. Setup fly
Give the app the name you want. Don't deploy yet.
```
git clone https://github.com/patte/fly-tailscale-exit.git

cd fly-tailscale-exit

fly launch

? fly.toml file already exits would you like copy its configuration : (yes/no) yes

? App Name (leave blank to use an auto-generated name) tailwings

? Select organization: banana-bender-net-test (banana-bender-net-test)

? would you like to deploy postgressql for the app: (yes/no) no

? would you like to deploy now : (yes/no) no
```

#### 9. Set the Tailscale authentication credentials in fly

##### If using Auth Key (Option A from step 5):
```
fly secrets set TAILSCALE_AUTH_KEY=[your auth key]
Secrets are staged for the first deployment
```

##### If using OAuth (Option B from step 5):
```
fly secrets set TAILSCALE_OAUTH_CLIENT_ID=[your OAuth client ID] TAILSCALE_OAUTH_SECRET=[your OAuth client secret]
Secrets are staged for the first deployment
```

#### 10 Deploy (and scale)

```
fly deploy
? Would you like to allocate a dedicated ipv4 address now? No
```
Answer **No** — you don't need a dedicated IPv4. Tailscale hole-punches a **direct** path through Fly's (endpoint-independent) NAT on its own, so a dedicated IPv4 does not improve connectivity for an exit node. (Verified: `tailscaled` advertises the machine's egress IP, never the Fly ingress IP, so the paid IP simply goes unused — which is why this `fly.toml` carries no `[[services]]` block.)

> Whether a given client gets a direct connection or falls back to Tailscale [DERP](https://tailscale.com/kb/1232/derp-servers) relays depends on the **client's** network: most home/office networks hole-punch straight to direct; hard CGNAT or some mobile hotspots stay on DERP (still works, just relayed). Nothing on the Fly node changes this.

At the time of writing fly deploys two machines per default. For this setup you probably want 1 machine per region. Run the following to remove the second machine:
```
fly scale count 1
```

You can check the logs with `fly logs`. If you encounter `Out of memory: Killed process 526 (tailscaled)` you might want to give the machine more memory with: `fly scale memory 512`.

#### 11. Enable exit node in tailscale
Wait for the node to appear in the tailscale machine overview.
Enable exit routing for the nodes https://login.tailscale.com/admin/machines (see [tailscale docs](https://tailscale.com/kb/1103/exit-nodes/#step-2-allow-the-exit-node-from-the-admin-panel) on how to do it)


#### 12. Connect with your local machine or smartphone
On iOS, choose "use exit node" and there you go.

On linux, just run
```
tailscale up --use-exit-node=fly-fra
```

#### 13. Regions
To add or remove regions just type:
```
fly scale count 1 --region hkg
fly scale count 1 --region fra

or:
fly scale count 3 --region hkg,fra,ams

or remove a machine explicitly:
fly status
fly machine stop $(machine_id)
fly machine destroy $(machine_id)
```
Wait for the node to appear in tailscale, confirm it to be a legit exit node (step 11), choose it in your client boom! In less than 5 minutes you access the internet from another place.<br/>
Note: See the [fly docs about scaling] for further info: https://fly.io/docs/apps/scale-count/ <br/>
Note: Scaling up also reinitializes the existing nodes. Just use the newly created one and delete the old.<br/>
Note: It seems that not all fly ips are correctly geo located or that not all fly regions have their own exit routers and some use another for egress traffic. This needs further investigation. See this [HN discussion](https://news.ycombinator.com/item?id=36064854) about it.

https://user-images.githubusercontent.com/3500621/129452587-7ff90cd2-5e6d-4e39-9a91-548c498636f5.mp4

#### Update tailscale
```
git pull
fly deploy --strategy immediate
```
Then manually remove the old nodes in tailscale and enable exit node in tailscale.


Checkout [this fork](https://github.com/StepBroBD/Tailscale-on-Fly.io/tree/stepbrobd-pr-feat-auto-deploy) for an approach to auto deploy to fly with a github action (including managing tailscale nodes with a python script).


#### Halt
In case you want to stop:
```
sudo systemctl stop tailscaled
fly suspend
```

#### Remove
In case you want to tear it down:
```
fly orgs delete banana-bender-net
```
[Request the deletion](https://tailscale.com/contact/support/?type=tailnetdeletion) of the tailnet.


### Optional: Auto approve exit nodes
To auto approve the fly machines as exit-nodes in tailscale. Add the following ACLs:
```json
{
  "tagOwners": {
    "tag:fly-exit": [
      "YOUR-USERNAME@github", // user creating the tailscale auth key (step 5)
    ],
  },
  "autoApprovers": {
    "exitNode": ["tag:fly-exit"],
  },
}
```
Then set the tag via a Fly secret and redeploy:
```
fly secrets set TAILSCALE_ADVERTISE_TAGS=tag:fly-exit
fly deploy --strategy immediate
```
([start.sh](start.sh) passes `TAILSCALE_ADVERTISE_TAGS` to `tailscale up --advertise-tags`, so no code edit is needed.)


## Invite your friends
All you need to do to invite friends into your network is to invite them to the github organization, have them install tailscale and login with github. They immediately see the available exit nodes and can use whichever they please.


## Troubleshooting

### `connmark` / `CONNMARK` warning in `fly logs` (harmless)

You may see this health warning from tailscaled in `fly logs` (or under `tailscale status`):

```
- enabling connmark rules: adding [-m conntrack --ctstate ESTABLISHED,RELATED -j CONNMARK --restore-mark --nfmask 0xff0000 --ctmask 0xff0000] in mangle/PREROUTING: running [/usr/sbin/iptables -t mangle -I PREROUTING 1 -m conntrack --ctstate ESTABLISHED,RELATED -j CONNMARK --restore-mark --nfmask 0xff0000 --ctmask 0xff0000 --wait]: exit status 2: Warning: Extension CONNMARK revision 0 not supported, missing kernel module?
iptables v1.8.11 (nf_tables): unknown option "--nfmask"
```

It's harmless and the exit node works fine. tailscaled uses a firewall mark (`fwmark`) plus `CONNMARK` to policy-route reply traffic, but that needs the `xt_CONNMARK` kernel module, which Fly's microVM kernel doesn't ship (`modprobe xt_CONNMARK` → `not found in modules.dep`). So tailscaled can't install that one rule. This is **not** an iptables-backend issue — switching `iptables` to the legacy backend (as the official Tailscale image does) hits the exact same missing module.

Exit traffic still works because [start.sh](start.sh) sets up `MASQUERADE` itself and the kernel's connection tracking handles the return path: replies are un-NAT'd back to the Tailscale client and routed over `tailscale0`, so the `fwmark` policy-routing isn't needed.


## Why this probably is a bad idea
- Dirty egress traffic for fly.io.<br>
Usually traffic exiting fly machines is upstream API traffic not dirty users surfing the web. If too many people do this and use it for scraping or worse fly's traffic reputation might suffer.

- Increased traffic on tailscale derp servers.<br>
  Usually tailscale is used for internal networks. If everybody uses this as their everyday VPN the traffic the derp servers might increase beyond what's forseen.

- Tailscale teams is supposed to cost money.<br>
  ~~Tailscale lists teams to [cost $5 per user per month](https://tailscale.com/pricing/) but creating and using a github org in the way described above doesn't count as team but as personal account. I didn't find a way to upgrade an org created this way into a paying org. Please let me pay ;)~~ It seems you can pay at tailscale for a github team now, so go there and do that if you use this together with others: https://login.tailscale.com/admin/settings/billing/plans This makes this VPN approach being fully paid.
> You’ll never be stopped from spinning up more devices or subnet routers, or trying out ACL rules. We encourage you to play around, find what works best for you, and update your payment settings after-the-fact.

[source](https://tailscale.com/blog/2021-06-new-pricing/)
Kudos to tailscale for using soft-limit, IMHO this makes for a great user experience and I'd expect it to simplify some code parts as well.

## Love Letter
Just enjoy the magnificence, the crazyness of the house of cards that the modern cloud is. I seriously enjoyed setting this up with fly and tailscale. I think both are mind blowingly awesome.

I mean tailscale... just look at it. The already awesome wireguard set up to a [mesh](https://tailscale.com/blog/how-tailscale-works/) by an open-source [client](https://github.com/tailscale/tailscale) that does [all sorts of NAT wizardry](https://tailscale.com/blog/how-nat-traversal-works/), provided servers to route through if P2P doesn't work and a nice web-ui. It's just great.
If I could wish for anything it would be to be able to run the server part myself (I know about [headscale](https://github.com/juanfont/headscale) and I'll give it a try next) . Not because I don't want to pay the company money, the contrary is the case, but because I just don't feel comfortable having my (bare-metal) machines trusting a network interface for which I can't fully control who is connected to the other end. Tailscale could auth a machine into my network and I'd have no possibility to reliably find out.


What gets me most about fly is the approach to turn Dockerfiles into microVMs. Imagine docker but with `--privileged --net=host`. This is what makes this example so simple in comparison to [other cloud providers](https://tailscale.com/kb/guides/): Just a neat Dockerfile and start script but you can use tailscale as if it would run on a real linux host, because it does. No need to [run tailscaled with](https://tailscale.com/kb/1107/heroku/) `--tun=userspace-networking --socks5-server=localhost:1055`, the tailscale interface get's added to the VM and everything just works. This includes that the [metrics gathered by fly](https://fly.io/docs/reference/metrics/) automatically include the `tailscale0` interface and you can view it's traffic chart in grafana easily.

![Screenshot from 2021-08-14 19-17-34](https://user-images.githubusercontent.com/3500621/129463128-0572ced3-13b7-4908-8477-6bb04049a658.png)

This plus anycast, interapp vpn, persistent storage, locations all over the world, an open-source [client](https://github.com/superfly/flyctl) and being a chatty crew with the mindset ["Go Nuts"](https://fly.io/blog/ssh-and-user-mode-ip-wireguard/) have me left in awe.

