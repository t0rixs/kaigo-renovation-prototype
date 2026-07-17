#!/usr/bin/env bash
set -euo pipefail

flutter build web --release --pwa-strategy=none "$@"
cp web/service_worker_retire.js build/web/flutter_service_worker.js
