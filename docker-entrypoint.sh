#!/bin/sh
set -eu


log() {
    printf '%s\n' "$*" >&2
}


die() {
    log "error: $*"
    exit 1
}


: "${XRAY_UUID:?XRAY_UUID is required}"


PORT="${PORT:-3000}"
WS_PATH="${XRAY_WS_PATH:-/ws}"
LOG_LEVEL="${XRAY_LOG_LEVEL:-warning}"
CONFIG_TEMPLATE="${XRAY_CONFIG_TEMPLATE:-/etc/xray/config.template.json}"
CONFIG_FILE="${XRAY_CONFIG_FILE:-/etc/xray/config.json}"
XRAY_BIN="${XRAY_BIN:-/usr/local/bin/xray}"


[ -x "${XRAY_BIN}" ] || die "xray binary not found or not executable: ${XRAY_BIN}"
[ -r "${CONFIG_TEMPLATE}" ] || die "config template not readable: ${CONFIG_TEMPLATE}"


case "${PORT}" in
    ''|*[!0-9]*) die "PORT must be numeric" ;;
esac


if [ "${PORT}" -lt 1 ] || [ "${PORT}" -gt 65535 ]; then
    die "PORT must be between 1 and 65535"
fi


case "${WS_PATH}" in
    /*) ;;
    *) WS_PATH="/${WS_PATH}" ;;
esac


case "${WS_PATH}" in
    *' '*) die "XRAY_WS_PATH must not contain spaces" ;;
esac


case "${WS_PATH}" in
    *[!A-Za-z0-9/_-]*) die "XRAY_WS_PATH may only contain letters, digits, slash, underscore, and hyphen" ;;
esac


case "${LOG_LEVEL}" in
    debug|info|warning|error|none) ;;
    *) die "XRAY_LOG_LEVEL must be debug, info, warning, error, or none" ;;
esac


printf '%s' "${XRAY_UUID}" | grep -Eq '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$' \
    || die "XRAY_UUID must be a valid RFC 4122 UUID"


escape_sed() {
    printf '%s' "$1" | sed 's/[\\&|]/\\&/g'
}


UUID_ESC="$(escape_sed "${XRAY_UUID}")"
PATH_ESC="$(escape_sed "${WS_PATH}")"
LEVEL_ESC="$(escape_sed "${LOG_LEVEL}")"


mkdir -p "$(dirname "${CONFIG_FILE}")"


sed \
    -e "s|__UUID__|${UUID_ESC}|g" \
    -e "s|__PORT__|${PORT}|g" \
    -e "s|__WS_PATH__|${PATH_ESC}|g" \
    -e "s|__LOG_LEVEL__|${LEVEL_ESC}|g" \
    "${CONFIG_TEMPLATE}" > "${CONFIG_FILE}"


chmod 0600 "${CONFIG_FILE}"


"${XRAY_BIN}" run -test -c "${CONFIG_FILE}" >/dev/null


log "starting xray on 0.0.0.0:${PORT}, ws_path=${WS_PATH}, tls=external"
exec "${XRAY_BIN}" run -c "${CONFIG_FILE}"

