ARG TSVERSION=1.74.1
ARG TSFILE=tailscale_${TSVERSION}_amd64.tgz

FROM alpine:latest as tailscale
ARG TSFILE
WORKDIR /app

RUN wget https://pkgs.tailscale.com/stable/${TSFILE} && \
  tar xzf ${TSFILE} --strip-components=1
COPY . ./


FROM alpine:latest
# alpine:3.19 links iptables to iptables-nft https://gitlab.alpinelinux.org/alpine/aports/-/commit/f87a191922955bcf5c5f3fc66a425263a4588d48.
# iptables-nft requires kernel support for nft, which is currently not available in Fly.io,
# so we remove the links and ensure that the iptables-legacy version is used.
RUN apk update && apk add ca-certificates iptables iptables-legacy ip6tables  \
  && rm -rf /var/cache/apk/* \
  && rm /sbin/iptables && ln -s /sbin/iptables-legacy /sbin/iptables  \
  && rm /sbin/ip6tables && ln -s /sbin/ip6tables-legacy /sbin/ip6tables


# creating directories for tailscale
RUN mkdir -p /var/run/tailscale
RUN mkdir -p /var/cache/tailscale
RUN mkdir -p /var/lib/tailscale

# Copy binary to production image
COPY --from=tailscale /app/tailscaled /app/tailscaled
COPY --from=tailscale /app/tailscale /app/tailscale
COPY --from=tailscale /app/start.sh /app/start.sh

# Run on container startup.
USER root
CMD ["/app/start.sh"]
