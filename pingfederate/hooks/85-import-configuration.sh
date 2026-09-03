#!/usr/bin/env sh
# Copyright © 2026 Ping Identity Corporation
# Custom override: adds retry for cluster/replicate and makes it non-fatal.
# The engine will pull config from the admin on its next connection even
# if the explicit replicate push fails.

# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

pf_admin_password="$(get_value PING_IDENTITY_PASSWORD true)"

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

    if test "${OPERATIONAL_MODE}" = "CLUSTERED_CONSOLE"; then
        # Wait for PF config reload to complete before replicating.
        # Without this sleep, the admin API may return 401 while auth
        # subsystem is reinitializing after the bulk import reload.
        echo "INFO: Waiting for config reload before replicating..."
        sleep 10

        _replicate_ok=false
        for _attempt in 1 2 3; do
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
                    --output "${api_output_file}" \
                    "https://localhost:${PF_ADMIN_PORT}/pf-admin-api/v1/cluster/replicate" \
                    2> /dev/null
            )
            stop_debug_logging

            if test "${http_response_code}" = "200"; then
                _replicate_ok=true
                break
            fi
            echo "WARN: Replicate attempt ${_attempt} returned ${http_response_code}, retrying in 5s..."
            sleep 5
        done

        if ! ${_replicate_ok}; then
            echo "WARN: Cluster replicate failed after 3 attempts (non-fatal)."
            echo "      Engine will sync config on next connection to admin."
            cat "${api_output_file}"
            # Non-fatal: do NOT exit 85 — the import succeeded and the
            # engine will pull config from admin on its next connection.
        fi
    fi
else
    echo_red "ERROR ${http_response_code}: Unable to import bulk config"
    cat "${api_output_file}"
    exit 85
fi

rm -f "${api_output_file}"
exit 0
