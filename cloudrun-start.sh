#!/usr/bin/env bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd "$SCRIPT_DIR" || exit

# Debug information
echo "===== Cloud Run Debug Info ====="
echo "Current directory: $(pwd)"
echo "Files in current directory:"
ls -la
echo "Environment variables (excluding secrets):"
env | grep -v SECRET | grep -v KEY | grep -v PASSWORD
echo "=========================="

KEY_FILE=.webui_secret_key

PORT="${PORT:-8080}"
HOST="${HOST:-0.0.0.0}"
if test "$WEBUI_SECRET_KEY $WEBUI_JWT_SECRET_KEY" = " "; then
  echo "Loading WEBUI_SECRET_KEY from file, not provided as an environment variable."

  if ! [ -e "$KEY_FILE" ]; then
    echo "Generating WEBUI_SECRET_KEY"
    # Generate a random value to use as a WEBUI_SECRET_KEY in case the user didn't provide one.
    echo $(head -c 12 /dev/random | base64) > "$KEY_FILE"
  fi

  echo "Loading WEBUI_SECRET_KEY from $KEY_FILE"
  WEBUI_SECRET_KEY=$(cat "$KEY_FILE")
fi

# Important for Cloud Run: explicitly log that we're starting the server
echo "Starting server on $HOST:$PORT..."

# Set offline mode to prevent model downloads at startup
export HF_HUB_OFFLINE=0

# Use minimal worker count for faster startup
echo "Starting uvicorn with minimal worker configuration..."
WEBUI_SECRET_KEY="$WEBUI_SECRET_KEY" exec uvicorn open_webui.main:app --host "$HOST" --port "$PORT" --forwarded-allow-ips '*' --workers 1 --log-level debug
