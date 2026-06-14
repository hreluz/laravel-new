#!/usr/bin/env bash

set -e

IMAGE="laravel-new-tests"

echo "Building test image..."
docker build -f Dockerfile.test -t "$IMAGE" .

echo ""
echo "Running tests..."
docker run --rm -v "$(pwd)":/work "$IMAGE"
