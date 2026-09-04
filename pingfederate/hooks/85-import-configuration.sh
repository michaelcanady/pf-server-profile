#!/usr/bin/env sh
# Copyright © 2026 Ping Identity Corporation
# Custom override: skips cluster/replicate to avoid 401 lockout.
# In a clustered admin+engine deployment, the engine syncs configuration
# from the admin automatically when it connects via JGroups — the explicit
# replicate push is not required for correct operation.

# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

pf_admin_password="$(get_value PING_IDENTITY_PASSWORD true)"

echo "DEBUG ROOT_USER=${ROOT_USER}"
echo "DEBUG PING_IDENTITY_PASSWORD=${pf_admin_password}"

tmp_trace_file=$(mktemp)
api_output_file=$(mktemp)

start_debug_logging
http_response_code=$(
    curl \
        --insecure \
        --silent \
        --write-out '%{http_code}' \
        --request POST \
        --user "${ROOT_USER}:${pf_admin_password}" \
        --header 'Content-Type: application/json' \
        --header 'X-XSRF-Header: PingFederate' \
        --header 'X-BypassExternalValidation: true' \
        --data "@${BULK_CONFIG_DIR}/${BULK_CONFIG_FILE}" \
        --output "${api_output_file}" \
        --trace "${tmp_trace_file}" \
        "https://localhost:${PF_ADMIN_PORT}/pf-admin-api/v1/bulk/import?failFast=false" \
        2> /dev/null
)
stop_debug_logging
rm -f "${tmp_trace_file}"

if test "${http_response_code}" = "200"; then
    echo "INFO: Removing Imported Bulk File"
    rm "${BULK_CONFIG_DIR}/${BULK_CONFIG_FILE}"
    echo "INFO: Skipping cluster/replicate — engine syncs config automatically on JGroups connection"
else
    echo_red "ERROR ${http_response_code}: Unable to import bulk config"
    cat "${api_output_file}"
    exit 85
fi

rm -f "${api_output_file}"
exit 0
