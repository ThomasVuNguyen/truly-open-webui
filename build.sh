#!/bin/bash
# build.sh - Script to build Docker image for Truly Open WebUI
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
  echo ""
  echo "Examples:"
  echo "  $0 --cuda --ollama              Build with CUDA and Ollama"
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
echo "Done!"
echo ""
echo "To deploy this image, run: ./deploy.sh"
