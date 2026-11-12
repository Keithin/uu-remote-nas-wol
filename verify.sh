#!/bin/sh
set -eu

docker compose --profile build config --quiet
grep -q 'fe052cdca7ad90d1ab7c27d031036b1071869070' README.md
grep -q 'UU_WOL_HELPER: "1"' compose.yaml
grep -q 'restart: unless-stopped' compose.yaml
grep -q 'network_mode: host' compose.yaml
grep -q 'cargo test --release --locked --bin uuremote-server wol::tests' compose.yaml

if grep -Ein '(/Users/|/tmp/zfsv3|/data_[[:alnum:]]+|100\.[0-9]+\.[0-9]+\.[0-9]+|192\.168\.[0-9]+\.[0-9]+|[[:alnum:]_.+-]+@[[:alnum:].-]+\.[[:alpha:]]{2,}|(ghp|github_pat)_[[:alnum:]_]+)' README.md compose.yaml; then
    echo 'Unexpected private address, local path or credential pattern' >&2
    exit 1
fi
