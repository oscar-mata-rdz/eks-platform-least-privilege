#!/usr/bin/env bash
set -euo pipefail

CHECKOV_IMAGE="bridgecrew/checkov:3.3.30"
CONFTEST_IMAGE="openpolicyagent/conftest:v0.71.1"

cd "$(dirname "$0")/.."
ROOT="$PWD"

checkov() {
  docker run --rm -v "$ROOT":/src -w /src "$CHECKOV_IMAGE" --config-file .checkov.yaml "$@"
}

conftest() {
  docker run --rm -v "$ROOT":/project -w /project "$CONFTEST_IMAGE" "$@"
}

echo "==> Rego tests"
conftest verify --policy policy/opa

echo
echo "==> Checkov (IAM)"
checkov -d modules -d platform

echo
echo "==> conftest"
tf_files=$(find modules platform -name '*.tf' -not -path '*/.terraform/*' | sort)
# shellcheck disable=SC2086
conftest test --parser hcl2 --policy policy/opa $tf_files

echo
echo "==> Canary (both must fail)"
if checkov -d policy/testdata/overly-permissive >/dev/null 2>&1; then
  echo "FAIL: Checkov passed the canary." >&2
  exit 1
fi
echo "ok: Checkov rejected it"

if conftest test --parser hcl2 --policy policy/opa policy/testdata/overly-permissive >/dev/null 2>&1; then
  echo "FAIL: conftest passed the canary." >&2
  exit 1
fi
echo "ok: conftest rejected it"

if [[ "${1:-}" == "--full" ]]; then
  echo
  echo "==> Full Checkov report (informational)"
  docker run --rm -v "$ROOT/modules":/src -w /src "$CHECKOV_IMAGE" \
    -d . --framework terraform --compact --quiet --soft-fail
fi

echo
echo "All checks passed."
