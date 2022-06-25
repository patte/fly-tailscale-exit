ARG TSFILE=tailscale_1.26.1_amd64.tgz

FROM alpine:latest as tailscale
ARG TSFILE
WORKDIR /app
#ENV TSFILE=tailscale_1.26.0_amd64.tgz
RUN wget https://pkgs.tailscale.com/stable/${TSFILE} && \
  tar xzf ${TSFILE} --strip-components=1
COPY . ./


FROM alpine:latest
RUN apk update && apk add ca-certificates iptables ip6tables iproute2 && rm -rf /var/cache/apk/*

# Copy binary to production image
COPY --from=tailscale /app/start.sh /app/start.sh
COPY --from=tailscale /app/tailscaled /app/tailscaled
COPY --from=tailscale /app/tailscale /app/tailscale
RUN mkdir -p /var/run/tailscale
RUN mkdir -p /var/cache/tailscale
RUN mkdir -p /var/lib/tailscale

# Run on container startup.
USER root
CMD ["/app/start.sh"]
