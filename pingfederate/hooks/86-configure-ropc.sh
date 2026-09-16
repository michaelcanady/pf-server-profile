#!/usr/bin/env sh
# Configures the ROPC validator mapping and access token mapping via direct
# admin API calls. Both are needed for grant_type=password to issue tokens.
# The bulk import schema rejects fields required by these resources, so they
# are created/updated here after the bulk import completes.

. "${HOOKS_DIR}/pingcommon.lib.sh"

pf_admin_password="$(get_value PING_IDENTITY_PASSWORD true)"
pf_api_base="https://localhost:${PF_ADMIN_PORT}/pf-admin-api/v1"

_pf_put_or_post() {
    path="${1}"
    payload="${2}"
    http_code=$(
        curl --insecure --silent --write-out "%{http_code}" --output /dev/null             --request PUT             --user "${ROOT_USER}:${pf_admin_password}"             --header "Content-Type: application/json"             --header "X-XSRF-Header: PingFederate"             --data "${payload}"             "${pf_api_base}${path}"             2>/dev/null
    )
    if test "${http_code}" = "404"; then
        # Strip the trailing ID segment to get the collection path for POST
        collection_path="$(echo "${path}" | sed "s|/[^/]*$||"  )"
        http_code=$(
            curl --insecure --silent --write-out "%{http_code}" --output /dev/null                 --request POST                 --user "${ROOT_USER}:${pf_admin_password}"                 --header "Content-Type: application/json"                 --header "X-XSRF-Header: PingFederate"                 --data "${payload}"                 "${pf_api_base}${collection_path}"                 2>/dev/null
        )
    fi
    echo "${http_code}"
}

# 1. ROPC validator mapping
echo "INFO: Configuring ROPC validator mapping (krustykrabpcv)"
validator_payload='{
  "id": "krustykrabpcv",
  "passwordCredentialValidatorRef": {"id": "krustykrabpcv"},
  "attributeSources": [],
  "attributeContractFulfillment": {
    "USER_KEY": {
      "source": {"type": "PASSWORD_CREDENTIAL_VALIDATOR"},
      "value": "username"
    }
  },
  "issuanceCriteria": {"conditionalCriteria": []}
}'
http_code="$(_pf_put_or_post /oauth/resourceOwnerCredentialsMappings/krustykrabpcv "${validator_payload}")"
if test "${http_code}" = "200" || test "${http_code}" = "201"; then
    echo "INFO: Validator mapping OK (HTTP ${http_code})"
else
    echo_red "ERROR ${http_code}: Failed to configure ROPC validator mapping"
fi

# 2. ROPC access token mapping -> dspjwtatm
echo "INFO: Configuring ROPC access token mapping (dspjwtatm-ropc)"
atm_payload='{
  "id": "dspjwtatm-ropc",
  "context": {
    "type": "RESOURCE_OWNER_CREDENTIALS",
    "contextRef": {"id": "krustykrabpcv"}
  },
  "accessTokenManagerRef": {"id": "dspjwtatm"},
  "attributeSources": [],
  "attributeContractFulfillment": {
    "sub":       {"source": {"type": "PASSWORD_CREDENTIAL_VALIDATOR"}, "value": "username"},
    "username":  {"source": {"type": "PASSWORD_CREDENTIAL_VALIDATOR"}, "value": "username"},
    "email":     {"source": {"type": "PASSWORD_CREDENTIAL_VALIDATOR"}, "value": "mail"},
    "given_name":{"source": {"type": "PASSWORD_CREDENTIAL_VALIDATOR"}, "value": "givenName"},
    "family_name":{"source": {"type": "PASSWORD_CREDENTIAL_VALIDATOR"}, "value": "sn"},
    "name":      {"source": {"type": "PASSWORD_CREDENTIAL_VALIDATOR"}, "value": "displayName"},
    "clearance": {"source": {"type": "PASSWORD_CREDENTIAL_VALIDATOR"}, "value": "clearance"},
    "nationality":{"source": {"type": "PASSWORD_CREDENTIAL_VALIDATOR"}, "value": "nationality"},
    "needToKnow":{"source": {"type": "PASSWORD_CREDENTIAL_VALIDATOR"}, "value": "needToKnow"},
    "groups":    {"source": {"type": "TEXT"}, "value": "dsp-standard"},
    "realm_access.roles": {"source": {"type": "NO_MAPPING"}}
  },
  "issuanceCriteria": {"conditionalCriteria": []}
}'
http_code="$(_pf_put_or_post /oauth/accessTokenMappings/dspjwtatm-ropc "${atm_payload}")"
if test "${http_code}" = "200" || test "${http_code}" = "201"; then
    echo "INFO: ROPC ATM mapping OK (HTTP ${http_code}), replicating"
    curl --insecure --silent --output /dev/null         --request POST         --user "${ROOT_USER}:${pf_admin_password}"         --header "Content-Type: application/json"         --header "X-XSRF-Header: PingFederate"         "${pf_api_base}/cluster/replicate"         2>/dev/null
else
    echo_red "ERROR ${http_code}: Failed to configure ROPC ATM mapping"
fi

exit 0
