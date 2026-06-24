ARG TSVERSION=1.98.4
ARG TSFILE=tailscale_${TSVERSION}_amd64.tgz

FROM alpine:latest as tailscale
ARG TSFILE
WORKDIR /app

RUN wget https://pkgs.tailscale.com/stable/${TSFILE} && \
  tar xzf ${TSFILE} --strip-components=1
COPY . ./

FROM alpine:latest
# busybox-extras provides httpd, used to serve the health check endpoint (see start.sh)
RUN apk update && apk add ca-certificates iptables ip6tables busybox-extras \
  && rm -rf /var/cache/apk/*

# creating directories for tailscale
RUN mkdir -p /var/run/tailscale
RUN mkdir -p /var/cache/tailscale
RUN mkdir -p /var/lib/tailscale

# directory served by httpd for the health check endpoint
RUN mkdir -p /var/www/cgi-bin

# Copy binary to production image
COPY --from=tailscale /app/tailscaled /app/tailscaled
COPY --from=tailscale /app/tailscale /app/tailscale
COPY --from=tailscale /app/start.sh /app/start.sh
COPY --from=tailscale /app/healthz /var/www/cgi-bin/healthz
RUN chmod +x /var/www/cgi-bin/healthz

# Run on container startup.
USER root
CMD ["/app/start.sh"]
