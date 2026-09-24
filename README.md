# pf-server-profile

Parameterized, **secret-free** PingFederate server profile for the DSP
support-team labs.

> The canonical copy lives in `virtru-corp/dsp-support-hacks` at
> `labbing/pingfederate/`. This public repo mirrors it.

## Secret-free / lab-agnostic

This profile ships no secrets and no lab-specific topology. Everything
environment-specific is injected at import time via `envsubst` over
`pingfederate/instance/bulk-config/data.json.subst`. A consumer **must** provide
every variable below or the bulk import substitutes empty values.

### Secret variables (inject from a secret manager)

| Variable | What it is |
|----------|-----------|
| `PING_IDENTITY_PASSWORD` | PingFederate admin password |
| `dataStores_items_ProvisionerDS_ProvisionerDS_password` | Provisioner datastore password |
| `keyPairs_sslServer_items_vtcm75en83g6v1r87ytm7lihi_vtcm75en83g6v1r87ytm7lihi_fileData` | SSL server keypair (PKCS12, base64) |
| `keyPairs_sslServer_items_vtcm75en83g6v1r87ytm7lihi_vtcm75en83g6v1r87ytm7lihi_password` | SSL server keypair password |
| `serverSettings_systemKeys_items_current_keyData` | PingFederate current system key |
| `serverSettings_systemKeys_items_pending_keyData` | PingFederate pending system key |
| `ldap_ad_bind_dn` | AD/LDAP bind DN |
| `ldap_ad_bind_password` | AD/LDAP bind password |

### Topology variables (non-secret)

| Variable | Example | What it is |
|----------|---------|-----------|
| `lab_domain` | `support-team-<lab>.dsp.lab` | Lab public FQDN suffix (platform / pf / pf-admin, redirect URIs, `federationInfo.baseUrl`) |
| `ldap_ad_hostname` | `domain1.<lab>.lab:389` | AD/LDAP host:port |
| `ldap_ad_base_dn` | `DC=<lab>,DC=lab` | AD base DN (search bases) |
| `sharepoint_host` | `sharepoint1.<lab>.lab` | SharePoint host (allowed redirect URL) |

> `${sub}` and `${username}` are PingFederate runtime expressions, not env vars —
> leave them unset.

### Master key

The PingFederate master encryption key (`pf.jwk`) is **not** in this repo; mount
it into the container at `/opt/out/instance/server/default/data/pf.jwk` from a
secret.

## ⚠️ History notice

Earlier revisions of this repo contained live secrets (system keys, an SSL
keypair, and passwords). Removing them from the current tree does **not** remove
them from git history — treat those values as compromised and **rotate** them.