#!/usr/bin/env sh
# Configures the ROPC validator mapping via direct admin API call.
# The bulk import API rejects passwordCredentialValidatorRef as an unknown
# field, so the mapping is created/updated here with the full model.

. "${HOOKS_DIR}/pingcommon.lib.sh"

pf_admin_password="$(get_value PING_IDENTITY_PASSWORD true)"

ropc_payload='{
  "id": "krustykrabpcv",
  "passwordCredentialValidatorRef": {
    "id": "krustykrabpcv"
  },
  "attributeSources": [
    {
      "type": "LDAP",
      "dataStoreRef": {"id": "krusty-krab-ad"},
      "id": "ad",
      "description": "ad",
      "baseDn": "CN=Users,DC=krusty-krab,DC=lab",
      "searchScope": "SUBTREE",
      "searchFilter": "sAMAccountName=${username}",
      "searchAttributes": [
        "mail", "givenName", "sn", "displayName",
        "clearance", "nationality", "needToKnow", "sAMAccountName"
      ],
      "binaryAttributeSettings": {},
      "memberOfNestedGroup": false
    }
  ],
  "attributeContractFulfillment": {
    "USER_KEY": {
      "source": {"type": "PASSWORD_CREDENTIAL_VALIDATOR"},
      "value": "username"
    }
  },
  "issuanceCriteria": {"conditionalCriteria": []}
}'

pf_api_base="https://localhost:${PF_ADMIN_PORT}/pf-admin-api/v1"
auth_args="--user "${ROOT_USER}:${pf_admin_password}""
common_headers="--header 'Content-Type: application/json' --header 'X-XSRF-Header: PingFederate'"

echo "INFO: Configuring ROPC validator mapping for krustykrabpcv"

# Try PUT (update) first; if 404, fall back to POST (create)
http_code=$(
    curl --insecure --silent --write-out '%{http_code}' --output /dev/null         --request PUT         --user "${ROOT_USER}:${pf_admin_password}"         --header 'Content-Type: application/json'         --header 'X-XSRF-Header: PingFederate'         --data "${ropc_payload}"         "${pf_api_base}/oauth/resourceOwnerCredentialsMappings/krustykrabpcv"         2>/dev/null
)

if test "${http_code}" = "404"; then
    echo "INFO: Mapping not found, creating via POST"
    http_code=$(
        curl --insecure --silent --write-out '%{http_code}' --output /dev/null             --request POST             --user "${ROOT_USER}:${pf_admin_password}"             --header 'Content-Type: application/json'             --header 'X-XSRF-Header: PingFederate'             --data "${ropc_payload}"             "${pf_api_base}/oauth/resourceOwnerCredentialsMappings"             2>/dev/null
    )
fi

if test "${http_code}" = "200" || test "${http_code}" = "201"; then
    echo "INFO: ROPC validator mapping configured (HTTP ${http_code}), replicating"
    curl --insecure --silent --output /dev/null         --request POST         --user "${ROOT_USER}:${pf_admin_password}"         --header 'Content-Type: application/json'         --header 'X-XSRF-Header: PingFederate'         "${pf_api_base}/cluster/replicate"         2>/dev/null
else
    echo_red "ERROR ${http_code}: Failed to configure ROPC validator mapping"
fi

exit 0
