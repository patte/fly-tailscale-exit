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
- Create an org with the same name in fly (technically there is no requirement to name it the same).
`fly orgs create banana-bender-net`
- Go and enter your credit card at [https://fly.io/organizations/banana-bender-net](https://fly.io/organizations). It's only going to be charged if you use more than the [free resources](https://fly.io/docs/about/pricing/).

#### 8. Setup fly
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
Wait for the node to appear in tailscale, confirm it to be a legit exit node (step 9), choose it in your client and in less than 5 minutes to access the internet in another place.
Note: Scaling up also reinitializes the existing nodes. Just use the newly created one and delete the old.
Note: It seems not all fly regions have their own exit routers and some use another for egress traffic. This needs further investigation.


#### 14. Enjoy
Just enjoy the magnificence, the crazyness of the house of cards that the modern cloud is.

#### 15. halt
```
sudo systemctl stop tailscaled
fly suspend
```

#### 16. remove
```
fly orgs delete banana-bender-net
```
I think there is no way to delete a tailscale org.


## Invite your friends
All you need to do to invite friends into your network is to invite them to the github organization, have them install tailscale and login with github. They immediately see the available exit nodes and can use whichever they please. Easiest VPN setup ever!!


## Why this probably is a bad idea
- Dirty traffic for fly.io.
	Usually traffic exiting fly machines is upstream API traffic not dirty users surfing the web. If too many people do this and use it for scraping or worse fly's traffic reputation might suffer.

- Increased traffic on tailscale derp servers.
  Usually tailscale is used for internal networks. If everybody uses this as their everyday VPN the traffic the derp servers might increase beyond what's forseen.

- Tailscale teams is supposed to cost money.
  Tailscale lists teams to [cost $5 per user per month](https://tailscale.com/pricing/) but creating and using a github org in the way described above doesn't count as team but as personal account. I didn't find a way to upgrade an org created this way into a paying org. Please let me pay ;)
