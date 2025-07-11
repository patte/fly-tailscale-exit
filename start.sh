#!/usr/bin/env sh

echo 'Starting up...'

# error: adding [-i tailscale0 -j MARK --set-mark 0x40000] in v4/filter/ts-forward: running [/sbin/iptables -t filter -A ts-forward -i tailscale0 -j MARK --set-mark 0x40000 --wait]: exit status 2: iptables v1.8.6 (legacy): unknown option "--set-mark"
modprobe xt_mark

echo 'net.ipv4.ip_forward = 1' | tee -a /etc/sysctl.conf
echo 'net.ipv6.conf.all.forwarding = 1' | tee -a /etc/sysctl.conf
sysctl -p /etc/sysctl.conf
#echo 'net.ipv6.conf.all.disable_policy = 1' | tee -a /etc/sysctl.conf

iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
ip6tables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

/app/tailscaled \
    --verbose=1 \
    --port 41641 \
    --state=mem: & # emphemeral-node mode (auto-remove)
    #--tun=userspace-networking
    #--socks5-server=localhost:1055

# Check if using OAuth or Auth Key
if [ -n "$TAILSCALE_OAUTH_CLIENT_ID" ] && [ -n "$TAILSCALE_OAUTH_SECRET" ]; then
    echo "Using OAuth authentication to generate an auth key"
    
    # Get an access token using the OAuth client credentials
    OAUTH_TOKEN_RESPONSE=$(wget --quiet --output-document=- --header="Content-Type: application/x-www-form-urlencoded" \
                           --post-data="client_id=${TAILSCALE_OAUTH_CLIENT_ID}&client_secret=${TAILSCALE_OAUTH_SECRET}" \
                           https://api.tailscale.com/api/v2/oauth/token)
    
    # Extract the access token
    ACCESS_TOKEN=$(echo $OAUTH_TOKEN_RESPONSE | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)
    
    if [ -z "$ACCESS_TOKEN" ]; then
        echo "Failed to get access token from Tailscale API"
        exit 1
    fi
    
    # Generate a new auth key using the access token
    AUTH_KEY_RESPONSE=$(wget --quiet --output-document=- --header="Content-Type: application/json" \
                        --header="Authorization: Bearer ${ACCESS_TOKEN}" \
                        --post-data='{"capabilities":{"devices":{"create":{"reusable":true,"ephemeral":false,"preauthorized":true,"tags":["tag:fly-exit"]}}}}' \
                        https://api.tailscale.com/api/v2/tailnet/-/keys)
    
    # Extract the auth key
    AUTH_KEY=$(echo $AUTH_KEY_RESPONSE | grep -o '"key":"[^"]*' | cut -d'"' -f4)
    
    if [ -z "$AUTH_KEY" ]; then
        echo "Failed to generate auth key from Tailscale API"
        exit 1
    fi
    
    echo "Successfully generated auth key using OAuth"
    
    # Use the generated auth key
    /app/tailscale up \
        --auth-key=${AUTH_KEY} \
        --hostname=fly-${FLY_REGION} \
        --advertise-exit-node #\
        #--advertise-tags=tag:fly-exit # requires ACL tagOwners
else
    # Use Auth Key authentication directly
    echo "Using Auth Key authentication"
    /app/tailscale up \
        --auth-key=${TAILSCALE_AUTH_KEY} \
        --hostname=fly-${FLY_REGION} \
        --advertise-exit-node #\
        #--advertise-tags=tag:fly-exit # requires ACL tagOwners
fi

echo "Tailscale started. Let's go!"
sleep infinity
