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

/app/tailscale up \
    --authkey=${TAILSCALE_AUTH_KEY} \
    --hostname=fly-${FLY_REGION} \
    --advertise-exit-node #\
    #--advertise-tags=tag:fly-exit # requires ACL tagOwners

echo "Tailscale started. Let's go!"
sleep infinity
