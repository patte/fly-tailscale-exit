fly-tailscale-exit
------------------

This repo shows how to run tailscale on fly, specifically to run exit nodes. The simple Dockerfile based on alpine can also be adapted to run tailscale along side your production app running on fly.

Did you ever need a wormhole to another place in the internet? But you didn't trust the shady VPN providers with ads all over YouTube?
Well, why not run it "yourself"? This guide helps you to set up a globally distributed and easyly sharable VPN service for you and your friends.
- Instantly scale up or down nodes arround the planet
- Choose where your traffic should exit the internet from 20 locations.
- Enjoy solid connections worldwide
- Bonus: the setup and the first 160GB of traffic each month are gratis

Sounds too good to be true. Well that's probably because it is. I compiled this setup as an excercise while exploring the capabilities of fly.io and tailscale. This is probably not what you should use as a serious VPN replacement. Go to one of the few trustworthy providers. For the reasons why this is a bad idea, read [below](#user-content-why-this-probably-is-a-bad-idea).



https://user-images.githubusercontent.com/3500621/129452512-616e7642-5a03-4037-9dc1-f6be96ca1e30.mp4

![Screenshot](https://user-images.githubusercontent.com/3500621/129452513-52133b60-02b8-4ec8-9605-0a6e3a089f9e.png)


## Setup

#### 1. Have GitHub account
Create an account on github if you don't have one already: https://github.com/signup

#### 2. Have GitHub organization
Let's create a new github org for your network: https://github.com/organizations/plan
- Choose a name for your network: eg. `banana-bender-net`
- Plan: free

#### 3. Have tailscale
Install tailscale on your machine(s):
- Instal it on your notebook and mobile phone: https://tailscale.com/download
- Login with github, choose the github organization created before (eg. `banana-bender-net`).
- Check your network and keep this window around: https://login.tailscale.com/admin/machines

#### 4. Setup DNS in tailscale
In order to use tailscale for exit traffic you need to configure a public DNS. Go to https://login.tailscale.com/admin/dns and add the nameservers of your choice (eg. cloudflare: `1.1.1.1, 1.0.0.1, 2606:4700:4700::1111, 2606:4700:4700::1001`)

#### 5. Create tailscale auth key
Create an reusable auth key in tailscale: https://login.tailscale.com/admin/settings/authkeys

_A ephemeral key would be better for our use case, but it's restricted to IPv6 only by tailscale, which doesn't work so well as a VPN exit node._


#### 6. Have fly.io account and cli
Install the cli to your machine and login with github: https://fly.io/docs/hands-on/installing/

#### 7. Have fly.io organization
- Go to https://fly.io/organizations/ and create an organization (or) you can create organization using fly.io cli 
- Create an org with the same name in fly (technically there is no requirement to name it the same).
`flyctl orgs create banana-bender-net`
- Go and enter your credit card at [https://fly.io/organizations/banana-bender-net](https://fly.io/organizations). It's only going to be charged if you use more than the [free resources](https://fly.io/docs/about/pricing/).

#### 8. Setup fly app 
```
git clone https://github.com/justforvpn/fly-tailscale-exit.git

cd fly-tailscale-exit

flyctl launch 
```
Deploy this app to fly. It's basically a Dockerfile that runs tailscale in alpine and a start stript to keep it running.
```
fly init --import=fly-template.toml

? App Name (leave blank to use an auto-generated name) tailwings

? Select organization: banana-bender-net-test (banana-bender-net-test)

Importing configuration from fly-template.toml
New app created
  Name         = tailwings
  Organization = banana-bender-net-test
  Version      = 0
  Status       =
  Hostname     = <empty>

App will initially deploy to fra (Frankfurt, Germany) region

Wrote config file fly.toml
```

#### 9. Set the tailscale auth key in fly
```
fly secrets set TAILSCALE_AUTH_KEY=[see step 4]
Secrets are staged for the first deployment
```

#### 10. Deploy
```
fly deploy
Deploying tailwings
==> Validating app configuration
--> Validating app configuration done
Services
UDP 41641 ⇢ 41641
Remote builder fly-builder-dawn-pond-6587 ready
==> Creating build context
--> Creating build context done
==> Building image with Docker
Sending build context to Docker daemon  17.28kB
Step 1/16 : ARG TSFILE=tailscale_1.12.3_amd64.tgz
[omitted]
--> Pushing image done
Image: registry.fly.io/tailwings:deployment-1628948198
Image size: 40 MB
==> Creating release
Release v0 created

You can detach the terminal anytime without stopping the deployment
Monitoring Deployment

1 desired, 1 placed, 1 healthy, 0 unhealthy
--> v0 deployed successfully
```

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
fly regions add hkg
fly scale count 2
```
Wait for the node to appear in tailscale, confirm it to be a legit exit node (step 11), choose it in your client and in less than 5 minutes to access the internet in another place.
Note: Scaling up also reinitializes the existing nodes. Just use the newly created one and delete the old.
Note: It seems not all fly regions have their own exit routers and some use another for egress traffic. This needs further investigation.

https://user-images.githubusercontent.com/3500621/129452587-7ff90cd2-5e6d-4e39-9a91-548c498636f5.mp4

#### 14. halt
In case you want to stop:
```
sudo systemctl stop tailscaled
fly suspend
```

#### 15. remove
In case you want to tear it down:
```
fly orgs delete banana-bender-net
```
I think there is no way to delete a tailscale org.

## Invite your friends
All you need to do to invite friends into your network is to invite them to the github organization, have them install tailscale and login with github. They immediately see the available exit nodes and can use whichever they please. Easiest VPN setup ever!!


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

