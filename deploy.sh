#!/bin/bash
# deploy.sh - Script to deploy Truly Open WebUI Docker image
# Created: June 13, 2025

set -e # Exit on any error

# Default values
IMAGE_NAME="truly-open-webui"
IMAGE_TAG="latest"
PORT="1001"
CONTAINER_NAME="truly-open-webui"
USE_OLLAMA="false"

# Print usage information
function show_help {
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  -h, --help                      Show this help message"
  echo "  -n, --name IMAGE_NAME           Docker image name to deploy (default: $IMAGE_NAME)"
  echo "  -t, --tag IMAGE_TAG             Docker image tag to deploy (default: $IMAGE_TAG)"
  echo "  -p, --port PORT                 Port to expose (default: $PORT)"
  echo "  --container-name NAME           Container name (default: $CONTAINER_NAME)"
  echo "  -o, --ollama                    Enable networking for Ollama integration"
  echo ""
  echo "Environment Variables:"
  echo "  OPENAI_API_KEY                  OpenAI API key"
  echo "  WEBUI_SECRET_KEY                WebUI secret key"
  echo ""
  echo "Examples:"
  echo "  $0                              Deploy with default settings"
  echo "  $0 --port 3000 --ollama         Deploy on port 3000 with Ollama support"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      show_help
      exit 0
      ;;
    -n|--name)
      IMAGE_NAME="$2"
      shift 2
      ;;
    -t|--tag)
      IMAGE_TAG="$2"
      shift 2
      ;;
    -p|--port)
      PORT="$2"
      shift 2
      ;;
    -o|--ollama)
      USE_OLLAMA="true"
      shift
      ;;
    --container-name)
      CONTAINER_NAME="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
done

echo "===== Truly Open WebUI Docker Deployment Script ====="
echo "Image:              $IMAGE_NAME:$IMAGE_TAG"
echo "Container name:     $CONTAINER_NAME"
echo "Port:               $PORT"
echo "Ollama enabled:     $USE_OLLAMA"
echo "================================================="

# Check if the image exists
if ! docker image inspect "$IMAGE_NAME:$IMAGE_TAG" &>/dev/null; then
  echo "Error: Image $IMAGE_NAME:$IMAGE_TAG not found."
  echo "Please build the image first using: ./build.sh"
  exit 1
fi

echo "Starting container: $CONTAINER_NAME"

# Stop existing container if it exists
if docker ps -a --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
  echo "Stopping and removing existing container: $CONTAINER_NAME"
  docker stop $CONTAINER_NAME >/dev/null 2>&1 || true
  docker rm $CONTAINER_NAME >/dev/null 2>&1 || true
fi

# Run the container
DOCKER_RUN_CMD="docker run -d --name $CONTAINER_NAME -p $PORT:8080"

# Add environment variables if provided
if [ -n "$OPENAI_API_KEY" ]; then
  echo "Using provided OpenAI API key"
  DOCKER_RUN_CMD+=" -e OPENAI_API_KEY=$OPENAI_API_KEY"
fi

if [ -n "$WEBUI_SECRET_KEY" ]; then
  echo "Using provided WebUI secret key"
  DOCKER_RUN_CMD+=" -e WEBUI_SECRET_KEY=$WEBUI_SECRET_KEY"
fi

# If Ollama is enabled, ensure proper networking
if [ "$USE_OLLAMA" = "true" ]; then
  echo "Setting up networking for Ollama integration..."
  DOCKER_RUN_CMD+=" --network host"
fi

# Add volume for persistence
DOCKER_RUN_CMD+=" -v ${CONTAINER_NAME}-data:/app/backend/data"

# Add the image name and tag
DOCKER_RUN_CMD+=" $IMAGE_NAME:$IMAGE_TAG"

# Execute the command
echo "Running: $DOCKER_RUN_CMD"
eval $DOCKER_RUN_CMD

echo "Container started successfully!"
echo "You can access Truly Open WebUI at: http://localhost:$PORT"
echo "To view logs: docker logs $CONTAINER_NAME"
echo "To stop container: docker stop $CONTAINER_NAME"
