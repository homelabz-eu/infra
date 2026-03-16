#!/bin/bash
HARBOR_URL="https://registry.homelabz.eu"
HARBOR_USER="admin"
HARBOR_PASS="$1"

if [ -z "$HARBOR_PASS" ]; then
  echo "Usage: $0 <harbor_admin_password>"
  exit 1
fi

DOCKERHUB_IDS=()
OTHER_IDS=()

for page in 1 2 3; do
  while IFS=$'\t' read -r id registry_id name; do
    [ -z "$id" ] && continue
    if [[ "$registry_id" == "7" ]]; then
      DOCKERHUB_IDS+=("$id")
    else
      OTHER_IDS+=("$id")
    fi
  done < <(curl -sk -u "$HARBOR_USER:$HARBOR_PASS" "$HARBOR_URL/api/v2.0/replication/policies?page_size=100&page=$page" | jq -r '.[] | "\(.id)\t\(.src_registry.id)\t\(.name)"')
done

echo "Found ${#DOCKERHUB_IDS[@]} Docker Hub policies and ${#OTHER_IDS[@]} other policies"

echo "--- Triggering non-Docker Hub policies (no rate limit) ---"
for id in "${OTHER_IDS[@]}"; do
  echo "Triggering policy $id..."
  curl -sk -u "$HARBOR_USER:$HARBOR_PASS" -X POST \
    "$HARBOR_URL/api/v2.0/replication/executions" \
    -H "Content-Type: application/json" \
    -d "{\"policy_id\": $id}" -o /dev/null -w "  HTTP %{http_code}\n"
  sleep 5
done

echo "--- Triggering Docker Hub policies (100 pulls/6h limit) ---"
for id in "${DOCKERHUB_IDS[@]}"; do
  echo "Triggering policy $id..."
  curl -sk -u "$HARBOR_USER:$HARBOR_PASS" -X POST \
    "$HARBOR_URL/api/v2.0/replication/executions" \
    -H "Content-Type: application/json" \
    -d "{\"policy_id\": $id}" -o /dev/null -w "  HTTP %{http_code}\n"
  sleep 60
done

echo "Done. All policies triggered."
