fly-tailscale-exit
------------------

![Action Status: auto update tailscale version](https://github.com/patte/fly-tailscale-exit/actions/workflows/auto-update-tailscale.yml/badge.svg)

This repo shows how to run tailscale on fly, specifically to run exit nodes.
If you want to add tailscale to a fly.io application, follow this guide instead: https://tailscale.com/kb/1132/flydotio/

⚠️ In September 2023 [Tailscale](https://tailscale.com/blog/mullvad-integration) and [Mullvad](https://mullvad.net/en/blog/tailscale-has-partnered-with-mullvad) announced to partner up: for $5/month you can use a mullvad exit node from up to 5 tailscale nodes. This is great news and I'd recommend to use this instead of the setup described here. Follow [this guide](https://tailscale.com/kb/1258/mullvad-exit-nodes) to set it up.


## Intro

Did you ever need a wormhole to another place in the internet? But you didn't trust the shady VPN providers with ads all over YouTube?
Well, why not run it "yourself"? This guide helps you to set up a globally distributed and easily sharable VPN service for you and your friends.
- Instantly scale up or down nodes around the planet
- Choose where your traffic exits to the internet from [30+ locations](https://fly.io/docs/reference/regions/).
- Enjoy solid connections worldwide
- ~~Bonus: the setup and the first 160GB of traffic each month are gratis.~~ _Update_: a dedicated IPv4 to enable P2P communication (not via DERP) now [costs $2/mo](https://fly.io/docs/about/pricing/#anycast-ip-addresses). _Update 2_: Fly.io's free tier (160/140GB) isn't meant for use by proxies. Your fly plan might get [upgraded to a $10/month “Advanced” plan](https://community.fly.io/t/4896). Thanks [@ignoramous](https://github.com/patte/fly-tailscale-exit/issues/37) for the heads up.


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

#### 5. Create a tailscale auth key
Create a reusable auth key in tailscale: https://login.tailscale.com/admin/settings/authkeys

_A ephemeral key would be better for our use case, but it's restricted to IPv6 only by tailscale, which doesn't work so well as a VPN exit node._


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

#### 9. Set the tailscale auth key in fly
```
fly secrets set TAILSCALE_AUTH_KEY=[see step 4]
Secrets are staged for the first deployment
```

#### 10 Deploy (and IP and scale)

```
fly deploy
? Would you like to allocate a dedicated ipv4 address now? Yes
```
_Update_: fly.io does [not automatically allocate a dedicated IPv4 per app on the first deployment anymore](https://community.fly.io/t/announcement-shared-anycast-ipv4/9384). You want a dedicated IPv4 to be able to expose the UDP port on it and thus enable peer-to-peer connections (not via tailscale DERP). You have three options:
- Say yes during the initial deploy.
- Run the command `fly ips allocate-v4` to add a dedicated IPv4 later
- Run `fly ips allocate-v6`. Direct connections to the node will only work if your local machine has a global IPv6. (not tested) 
- Remove the `services.ports` section from fly.toml. This has the disadvantage that your node is never going to be directly reachable and all your traffic is routed via tailscale DERP servers.

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
Then uncomment `--advertise-tags=tag:fly-exit` (and `\` on the previous line) in [start.sh](start.sh) and deploy `fly deploy --strategy immediate`.


## Invite your friends
All you need to do to invite friends into your network is to invite them to the github organization, have them install tailscale and login with github. They immediately see the available exit nodes and can use whichever they please.


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

