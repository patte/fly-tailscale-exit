ARG TSVERSION=1.54.1
ARG TSFILE=tailscale_${TSVERSION}_amd64.tgz

FROM alpine:latest as tailscale
ARG TSFILE
WORKDIR /app

RUN wget https://pkgs.tailscale.com/stable/${TSFILE} && \
  tar xzf ${TSFILE} --strip-components=1
COPY . ./


FROM alpine:latest
RUN apk update && apk add ca-certificates iptables ip6tables iproute2 && rm -rf /var/cache/apk/*

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
