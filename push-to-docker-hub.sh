#!/bin/bash
# push-to-docker-hub.sh - Script to push Truly Open WebUI Docker image to Docker Hub
# Created: June 13, 2025

set -e # Exit on any error

# Default values
LOCAL_IMAGE_NAME="truly-open-webui"
LOCAL_IMAGE_TAG="latest"
DOCKER_HUB_USERNAME=""
REPOSITORY_NAME="truly-open-webui" # Default repository name
DOCKER_HUB_TAG="latest"
SKIP_LOGIN="false"

# Print usage information
function show_help {
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  -h, --help                     Show this help message"
  echo "  -u, --username USERNAME        Your Docker Hub username (required)"
  echo "  -r, --repo REPOSITORY          Docker Hub repository name (default: truly-open-webui)"
  echo "  -t, --tag TAG                  Tag to use on Docker Hub (default: latest)"
  echo "  --local-image IMAGE_NAME       Local image name (default: truly-open-webui)"
  echo "  --local-tag TAG                Local image tag (default: latest)"
  echo "  --skip-login                   Skip Docker Hub login step (if already logged in)"
  echo ""
  echo "Example:"
  echo "  $0 --username myusername"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      show_help
      exit 0
      ;;
    -u|--username)
      DOCKER_HUB_USERNAME="$2"
      shift 2
      ;;
    -r|--repo)
      REPOSITORY_NAME="$2"
      shift 2
      ;;
    -t|--tag)
      DOCKER_HUB_TAG="$2"
      shift 2
      ;;
    --local-image)
      LOCAL_IMAGE_NAME="$2"
      shift 2
      ;;
    --local-tag)
      LOCAL_IMAGE_TAG="$2"
      shift 2
      ;;
    --skip-login)
      SKIP_LOGIN="true"
      shift
      ;;
    *)
      echo "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
done

# Check if username is provided
if [ -z "$DOCKER_HUB_USERNAME" ]; then
  echo "Error: Docker Hub username is required."
  echo "Please provide your username using the -u or --username option."
  show_help
  exit 1
fi

echo "===== Docker Hub Push Configuration ====="
echo "Local image:          $LOCAL_IMAGE_NAME:$LOCAL_IMAGE_TAG"
echo "Docker Hub username:  $DOCKER_HUB_USERNAME"
echo "Docker Hub repo:      $REPOSITORY_NAME"
echo "Docker Hub tag:       $DOCKER_HUB_TAG"
echo "========================================="

# Check if the local image exists
if ! docker image inspect "$LOCAL_IMAGE_NAME:$LOCAL_IMAGE_TAG" &>/dev/null; then
  echo "Error: Local image $LOCAL_IMAGE_NAME:$LOCAL_IMAGE_TAG not found."
  echo "Please build the image first using: ./build.sh"
  exit 1
fi

# Login to Docker Hub (unless skipped)
if [ "$SKIP_LOGIN" = "false" ]; then
  echo "Logging in to Docker Hub..."
  echo "Please enter your Docker Hub password when prompted."
  docker login -u "$DOCKER_HUB_USERNAME"
fi

# Tag the image for Docker Hub
DOCKER_HUB_IMAGE="$DOCKER_HUB_USERNAME/$REPOSITORY_NAME:$DOCKER_HUB_TAG"
echo "Tagging image as $DOCKER_HUB_IMAGE..."
docker tag "$LOCAL_IMAGE_NAME:$LOCAL_IMAGE_TAG" "$DOCKER_HUB_IMAGE"

# Push the image to Docker Hub
echo "Pushing image to Docker Hub..."
echo "This may take some time depending on your internet connection..."
docker push "$DOCKER_HUB_IMAGE"

echo "Success! Your image is now available at Docker Hub as:"
echo "$DOCKER_HUB_IMAGE"
echo ""
echo "You can pull this image on any machine with:"
echo "docker pull $DOCKER_HUB_IMAGE"
echo ""
echo "For Google Cloud Run deployment, use this image URL in your configuration."
