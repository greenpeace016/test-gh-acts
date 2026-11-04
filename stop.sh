set -euo pipefail
ENV="${ENV:-.env}"
export $(grep -v '^#' "$ENV" | xargs)
curl -X POST http://my-temp-runner:9000/stop -H "Authorization: Bearer $STOP_TOKEN"
