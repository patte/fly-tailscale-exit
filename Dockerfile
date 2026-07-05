ARG TSVERSION=1.98.8
ARG TSFILE=tailscale_${TSVERSION}_amd64.tgz

FROM alpine:3.24 AS tailscale
ARG TSFILE
WORKDIR /app

RUN wget https://pkgs.tailscale.com/stable/${TSFILE} && \
  tar xzf ${TSFILE} --strip-components=1

FROM alpine:3.24
# busybox-extras provides httpd, used to serve the health check endpoint (see start.sh)
RUN apk add --no-cache ca-certificates iptables ip6tables busybox-extras ethtool

# tailscale state dirs + the directory httpd serves the health check from
RUN mkdir -p /var/run/tailscale /var/cache/tailscale /var/lib/tailscale /var/www/cgi-bin

# tailscale binaries from the build stage; our scripts straight from the build context
COPY --from=tailscale /app/tailscaled /app/tailscale /app/
COPY start.sh /app/start.sh
COPY healthz /var/www/cgi-bin/healthz
RUN chmod +x /app/start.sh /var/www/cgi-bin/healthz

# Run on container startup.
CMD ["/app/start.sh"]
