# Netbox

Example API calls via `curl`:

```bash
# Get prefixes
TOKEN=$( \
    bw get item e8c3d331-3b79-4986-8977-b2a3001b1842 | \
    jq -r '.fields[] | select(.name=="api_token") | .value' \
)
curl \
    --silent \
    --request GET \
    --url https://netbox.fh.dronen.house/api/ipam/prefixes/ \
    --header "Authorization: Token ${TOKEN}" \
    --header "Content-Type: application/json" | \
    jq

# Get next available IP in prefix
curl \
    --silent \
    --request GET \
    --url https://netbox.fh.dronen.house/api/ipam/prefixes/1/available-ips/ \
    --header "Authorization: Token ${TOKEN}" \
    --header "Content-Type: application/json" | \
    jq
```
