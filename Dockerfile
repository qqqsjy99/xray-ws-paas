# syntax=docker/dockerfile:1.7
ARG XRAY_IMAGE=ghcr.io/xtls/xray-core:26.10.31
FROM ${XRAY_IMAGE} AS xray
FROM alpine:3.22
RUN apk add --no-cache ca-certificates tzdata \
    && addgroup -S -g 10001 xray \
    && adduser -S -D -H -u 10001 -G xray xray \
    && mkdir -p /etc/xray /var/log/xray \
    && chown -R xray:xray /etc/xray /var/log/xray
COPY --from=xray /usr/local/bin/xray /usr/local/bin/xray
COPY config.template.json /etc/xray/config.template.json
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod 0755 /usr/local/bin/xray /usr/local/bin/docker-entrypoint.sh \
    && chmod 0644 /etc/xray/config.template.json
ENV PORT=3000 XRAY_WS_PATH=/ws XRAY_LOG_LEVEL=warning
USER 10001:10001
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD nc -z 127.0.0.1 "${PORT}" || exit 1
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
