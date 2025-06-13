#!/bin/bash
# build-cloudrun.sh - Build a Cloud Run optimized version of Truly Open WebUI
# Created: June 13, 2025

set -e # Exit on any error

echo "===== Building Cloud Run Optimized Image ====="
echo "Creating simplified build with:"
echo "- Disabled CUDA (not supported on Cloud Run)"
echo "- Disabled Ollama (avoid startup delays)"
echo "- Minimal model configuration"
echo "- Optimized for Cloud Run environment"

# Create a temporary cloud-run specific start script
cat > cloudrun-start.sh << 'EOF'
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
EOF

chmod +x cloudrun-start.sh

# Create a temporary Dockerfile for Cloud Run
cat > Dockerfile.cloudrun << 'EOF'
FROM python:3.11-slim

ARG UID=1000
ARG GID=1000
ARG USE_EMBEDDING_MODEL="BAAI/bge-small-en-v1.5"

ENV USE_CUDA_DOCKER=false
ENV USE_OLLAMA_DOCKER=false
ENV USE_EMBEDDING_MODEL=${USE_EMBEDDING_MODEL}
ENV DOCKER=true

# Install dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl \
    gcc \
    g++ \
    python3-dev \
    git \
    jq \
    netcat-traditional && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create user
RUN groupadd -g $GID -o webui && \
    useradd -m -u $UID -g $GID -o -s /bin/bash webui

# Set up app directory
WORKDIR /app
COPY --chown=$UID:$GID . /app/
COPY --chown=$UID:$GID cloudrun-start.sh /app/backend/start.sh

# Install Python dependencies
WORKDIR /app/backend
RUN pip install --no-cache-dir -r requirements.txt

# Set proper permissions
RUN chown -R $UID:$GID /app

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=3 \
  CMD curl --silent --fail http://localhost:${PORT:-8080}/health || exit 1

USER $UID:$GID

CMD [ "bash", "start.sh" ]
EOF

# Build the image
echo "Building Cloud Run optimized image..."
docker build -t truly-open-webui:cloudrun -f Dockerfile.cloudrun .

# Tag for Docker Hub
echo "Tagging image for Docker Hub..."
docker tag truly-open-webui:cloudrun thomasthemaker/truly-open-webui:cloudrun

# Push to Docker Hub
echo "Do you want to push the image to Docker Hub? (y/n)"
read -r push_response
if [ "$push_response" = "y" ] || [ "$push_response" = "Y" ]; then
  echo "Pushing image to Docker Hub..."
  docker push thomasthemaker/truly-open-webui:cloudrun
  echo "Successfully pushed thomasthemaker/truly-open-webui:cloudrun to Docker Hub"
fi

echo ""
echo "===== Cloud Run Deployment Instructions ====="
echo "Deploy to Cloud Run with:"
echo ""
echo "gcloud run deploy truly-open-webui \\"
echo "  --image thomasthemaker/truly-open-webui:cloudrun \\"
echo "  --platform managed \\"
echo "  --region us-central1 \\"
echo "  --memory 2Gi \\"
echo "  --cpu 1 \\"
echo "  --timeout 600s \\"
echo "  --allow-unauthenticated"
echo ""
echo "If you need to specify API keys, add:"
echo "  --set-env-vars=\"OPENAI_API_KEY=your_key,WEBUI_SECRET_KEY=your_secret\""
echo ""
echo "If you want to use the deploy-to-cloud-run.sh script, run:"
echo "./deploy-to-cloud-run.sh --project YOUR_PROJECT_ID --image thomasthemaker/truly-open-webui:cloudrun"
