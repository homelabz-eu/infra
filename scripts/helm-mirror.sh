#!/usr/bin/env bash
set -euo pipefail

HARBOR_REGISTRY="${HARBOR_REGISTRY:-registry.homelabz.eu}"
HARBOR_PROJECT="${HARBOR_PROJECT:-helm-charts}"
CHARTS_FILE="${CHARTS_FILE:-$(dirname "$0")/helm-charts.yaml}"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

if ! command -v yq &>/dev/null; then
  echo "ERROR: yq is required but not installed"
  exit 1
fi

if ! helm registry login "$HARBOR_REGISTRY" 2>/dev/null; then
  echo "ERROR: failed to login to $HARBOR_REGISTRY"
  echo "Run: helm registry login $HARBOR_REGISTRY"
  exit 1
fi

CHART_COUNT=$(yq '.charts | length' "$CHARTS_FILE")
echo "Mirroring $CHART_COUNT charts to $HARBOR_REGISTRY/$HARBOR_PROJECT"
echo "---"

FAILED=0
SKIPPED=0
SUCCESS=0

for i in $(seq 0 $((CHART_COUNT - 1))); do
  NAME=$(yq -r ".charts[$i].name" "$CHARTS_FILE")
  REPO=$(yq -r ".charts[$i].repo" "$CHARTS_FILE")
  VERSION=$(yq -r ".charts[$i].version" "$CHARTS_FILE")

  echo "[$((i + 1))/$CHART_COUNT] $NAME:$VERSION"

  REPO_NAME="helm-mirror-${NAME}"
  helm repo add "$REPO_NAME" "$REPO" --force-update >/dev/null 2>&1 || true
  helm repo update "$REPO_NAME" >/dev/null 2>&1 || true

  if ! helm pull "$REPO_NAME/$NAME" --version "$VERSION" --destination "$TMPDIR" 2>/dev/null; then
    echo "  WARN: failed to pull $NAME:$VERSION, skipping"
    FAILED=$((FAILED + 1))
    continue
  fi

  CHART_FILE=$(ls "$TMPDIR"/${NAME}-*.tgz 2>/dev/null | head -1)
  if [ -z "$CHART_FILE" ]; then
    echo "  WARN: chart file not found after pull, skipping"
    FAILED=$((FAILED + 1))
    continue
  fi

  if helm push "$CHART_FILE" "oci://$HARBOR_REGISTRY/$HARBOR_PROJECT" 2>/dev/null; then
    echo "  OK"
    SUCCESS=$((SUCCESS + 1))
  else
    echo "  WARN: failed to push $NAME:$VERSION"
    FAILED=$((FAILED + 1))
  fi

  rm -f "$CHART_FILE"
done

helm repo list 2>/dev/null | grep '^helm-mirror-' | awk '{print $1}' | xargs -I{} helm repo remove {} 2>/dev/null || true

echo "---"
echo "Done: $SUCCESS pushed, $FAILED failed, $SKIPPED skipped"
