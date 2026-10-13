#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
# The app uses HTTP JSON; only auth message types are needed by the gateway.
# Requires protoc and dart pub global activate protoc_plugin.
generated_dir=$(mktemp -d)
trap 'rm -rf "$generated_dir"' EXIT HUP INT TERM
protoc --plugin="protoc-gen-dart=${PUB_CACHE:-$HOME/.pub-cache}/bin/protoc-gen-dart" \
  --dart_out="$generated_dir" -I api/proto api/proto/auth.proto
cp "$generated_dir/auth.pb.dart" lib/api/generated/auth.pb.dart
