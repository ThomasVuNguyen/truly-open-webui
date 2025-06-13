#!/bin/bash
# build-and-deploy.sh - Script to automate Docker build and deployment for Truly Open WebUI
# Created: June 13, 2025

set -e # Exit on any error

# Default values
IMAGE_NAME="truly-open-webui"
IMAGE_TAG="latest"
USE_CUDA="false"
USE_OLLAMA="false"
USE_CUDA_VER="cu121"
USE_EMBEDDING_MODEL="sentence-transformers/all-MiniLM-L6-v2"
USE_RERANKING_MODEL=""
DEPLOY_AFTER_BUILD="false"
PORT="1001"
CONTAINER_NAME="truly-open-webui"

# Print usage information
function show_help {
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  -h, --help                      Show this help message"
  echo "  -n, --name IMAGE_NAME           Set the Docker image name (default: $IMAGE_NAME)"
  echo "  -t, --tag IMAGE_TAG             Set the Docker image tag (default: $IMAGE_TAG)"
  echo "  -c, --cuda                      Enable CUDA support"
  echo "  -o, --ollama                    Include Ollama in the build"
  echo "  --cuda-version VER              Set CUDA version (default: $USE_CUDA_VER)"
  echo "  --embedding-model MODEL         Set embedding model (default: $USE_EMBEDDING_MODEL)"
  echo "  --reranking-model MODEL         Set reranking model"
  echo "  -r, --run                       Run the container after building"
  echo "  -p, --port PORT                 Port to expose (default: $PORT)"
  echo "  --container-name NAME           Container name (default: $CONTAINER_NAME)"
  echo ""
  echo "Environment Variables:"
  echo "  OPENAI_API_KEY                  OpenAI API key"
  echo "  WEBUI_SECRET_KEY                WebUI secret key"
  echo ""
  echo "Examples:"
  echo "  $0 --cuda --ollama --run        Build with CUDA and Ollama, then run"
  echo "  $0 --embedding-model \"intfloat/multilingual-e5-base\" --tag v1.0"
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
    -c|--cuda)
      USE_CUDA="true"
      shift
      ;;
    -o|--ollama)
      USE_OLLAMA="true"
      shift
      ;;
    --cuda-version)
      USE_CUDA_VER="$2"
      shift 2
      ;;
    --embedding-model)
      USE_EMBEDDING_MODEL="$2"
      shift 2
      ;;
    --reranking-model)
      USE_RERANKING_MODEL="$2"
      shift 2
      ;;
    -r|--run)
      DEPLOY_AFTER_BUILD="true"
      shift
      ;;
    -p|--port)
      PORT="$2"
      shift 2
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

echo "===== Truly Open WebUI Docker Build Script ====="
echo "Image name:       $IMAGE_NAME:$IMAGE_TAG"
echo "CUDA enabled:     $USE_CUDA"
echo "Ollama included:  $USE_OLLAMA"
echo "CUDA version:     $USE_CUDA_VER"
echo "Embedding model:  $USE_EMBEDDING_MODEL"
echo "Reranking model:  $USE_RERANKING_MODEL"
echo "Deploy after:     $DEPLOY_AFTER_BUILD"
echo "============================================="

# Build the Docker image
echo "Building Docker image..."

# Create a temporary Dockerfile with platform issue fixed
echo "Creating temporary Dockerfile..."
cp Dockerfile Dockerfile.temp
sed -i 's/--platform=\$BUILDPLATFORM/--platform=linux\/amd64/g' Dockerfile.temp

# Build using the temporary Dockerfile
docker build \
  --build-arg USE_CUDA=$USE_CUDA \
  --build-arg USE_OLLAMA=$USE_OLLAMA \
  --build-arg USE_CUDA_VER=$USE_CUDA_VER \
  --build-arg USE_EMBEDDING_MODEL="$USE_EMBEDDING_MODEL" \
  --build-arg USE_RERANKING_MODEL="$USE_RERANKING_MODEL" \
  -t $IMAGE_NAME:$IMAGE_TAG \
  -f Dockerfile.temp \
  .

# Clean up temporary Dockerfile
echo "Cleaning up temporary Dockerfile..."
rm Dockerfile.temp

echo "Docker image built successfully: $IMAGE_NAME:$IMAGE_TAG"

# Deploy if requested
if [ "$DEPLOY_AFTER_BUILD" = "true" ]; then
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
    DOCKER_RUN_CMD+=" -e OPENAI_API_KEY=$OPENAI_API_KEY"
  fi
  
  if [ -n "$WEBUI_SECRET_KEY" ]; then
    DOCKER_RUN_CMD+=" -e WEBUI_SECRET_KEY=$WEBUI_SECRET_KEY"
  fi
  
  # If Ollama is included and we're deploying the container, ensure proper networking
  if [ "$USE_OLLAMA" = "true" ]; then
    echo "Setting up networking for Ollama integration..."
    DOCKER_RUN_CMD+=" --network host"
  fi
  
  # Add volume for persistence
  DOCKER_RUN_CMD+=" -v ${IMAGE_NAME}-data:/app/backend/data"
  
  # Add the image name and tag
  DOCKER_RUN_CMD+=" $IMAGE_NAME:$IMAGE_TAG"
  
  # Execute the command
  echo "Running: $DOCKER_RUN_CMD"
  eval $DOCKER_RUN_CMD
  
  echo "Container started successfully!"
  echo "You can access Truly Open WebUI at: http://localhost:$PORT"
  echo "To view logs: docker logs $CONTAINER_NAME"
  echo "To stop container: docker stop $CONTAINER_NAME"
fi

echo "Done!"
