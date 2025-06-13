#!/bin/bash
# deploy-to-cloud-run.sh - Script to deploy Truly Open WebUI to Google Cloud Run
# Created: June 13, 2025

set -e # Exit on any error

# Default values
PROJECT_ID=""
REGION="us-central1"
SERVICE_NAME="truly-open-webui"
IMAGE_NAME="thomasthemaker/truly-open-webui:latest"
PORT=8080
CPU=2
MEMORY="4Gi"
MIN_INSTANCES=0
MAX_INSTANCES=10
CONCURRENCY=80
TIMEOUT="300s"
ENV_VARS=""
CLOUDSQL_INSTANCES=""
VPC_CONNECTOR=""
INGRESS="all"
AUTHENTICATE=false
SERVICE_ACCOUNT=""

# Print usage information
function show_help {
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  -h, --help                     Show this help message"
  echo "  -p, --project PROJECT_ID       GCP Project ID (required)"
  echo "  -r, --region REGION            GCP Region (default: us-central1)"
  echo "  -n, --name SERVICE_NAME        Service name (default: truly-open-webui)"
  echo "  -i, --image IMAGE_NAME         Docker image name (default: thomasthemaker/truly-open-webui:latest)"
  echo "  --port PORT                    Container port (default: 8080)"
  echo "  --cpu CPU                      CPUs to allocate (default: 1)"
  echo "  --memory MEMORY                Memory to allocate (default: 2Gi)"
  echo "  --min-instances MIN            Minimum instances (default: 0)"
  echo "  --max-instances MAX            Maximum instances (default: 10)"
  echo "  --concurrency NUM              Concurrency per instance (default: 80)"
  echo "  --timeout DURATION             Request timeout (default: 300s)"
  echo "  --env KEY=VALUE                Environment variables (can be used multiple times)"
  echo "  --sql INSTANCE                 Cloud SQL instance connection name"
  echo "  --vpc CONNECTOR                VPC connector name"
  echo "  --ingress TYPE                 Ingress setting (default: all)"
  echo "  --service-account EMAIL        Service account email"
  echo "  --authenticate                 Require authentication (default: public)"
  echo ""
  echo "Example:"
  echo "  $0 --project my-gcp-project --env OPENAI_API_KEY=my-api-key"
  echo ""
  echo "For more information about Google Cloud Run options, visit:"
  echo "https://cloud.google.com/sdk/gcloud/reference/run/deploy"
}

# Parse command line arguments
ENV_VAR_LIST=()

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      show_help
      exit 0
      ;;
    -p|--project)
      PROJECT_ID="$2"
      shift 2
      ;;
    -r|--region)
      REGION="$2"
      shift 2
      ;;
    -n|--name)
      SERVICE_NAME="$2"
      shift 2
      ;;
    -i|--image)
      IMAGE_NAME="$2"
      shift 2
      ;;
    --port)
      PORT="$2"
      shift 2
      ;;
    --cpu)
      CPU="$2"
      shift 2
      ;;
    --memory)
      MEMORY="$2"
      shift 2
      ;;
    --min-instances)
      MIN_INSTANCES="$2"
      shift 2
      ;;
    --max-instances)
      MAX_INSTANCES="$2"
      shift 2
      ;;
    --concurrency)
      CONCURRENCY="$2"
      shift 2
      ;;
    --timeout)
      TIMEOUT="$2"
      shift 2
      ;;
    --env)
      ENV_VAR_LIST+=("$2")
      shift 2
      ;;
    --sql)
      CLOUDSQL_INSTANCES="$2"
      shift 2
      ;;
    --vpc)
      VPC_CONNECTOR="$2"
      shift 2
      ;;
    --ingress)
      INGRESS="$2"
      shift 2
      ;;
    --authenticate)
      AUTHENTICATE=true
      shift
      ;;
    --service-account)
      SERVICE_ACCOUNT="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
done

# Check if project ID is provided
if [ -z "$PROJECT_ID" ]; then
  echo "Error: Project ID is required."
  echo "Please provide your GCP project ID using the -p or --project option."
  show_help
  exit 1
fi

# Build the environment variables string
# Always include PORT to match Cloud Run's expected port
ENV_VAR_LIST+=("PORT=$PORT")

if [ ${#ENV_VAR_LIST[@]} -gt 0 ]; then
  ENV_VARS=$(printf "%s," "${ENV_VAR_LIST[@]}")
  ENV_VARS=${ENV_VARS%,} # Remove trailing comma
fi

echo "===== Google Cloud Run Configuration ====="
echo "Project ID:             $PROJECT_ID"
echo "Region:                 $REGION"
echo "Service name:           $SERVICE_NAME"
echo "Image:                  $IMAGE_NAME"
echo "Port:                   $PORT"
echo "CPU:                    $CPU"
echo "Memory:                 $MEMORY"
echo "Min instances:          $MIN_INSTANCES"
echo "Max instances:          $MAX_INSTANCES"
echo "Concurrency:            $CONCURRENCY"
echo "Timeout:                $TIMEOUT"
echo "Authentication:         $([ "$AUTHENTICATE" = true ] && echo "Required" || echo "Public")"
echo "========================================="

# Ensure user is logged in and using the right project
echo "Setting GCP project to $PROJECT_ID..."
gcloud config set project "$PROJECT_ID"

# Enable necessary services
echo "Enabling required Google Cloud services..."
gcloud services enable cloudbuild.googleapis.com run.googleapis.com artifactregistry.googleapis.com

# Build the deployment command
CMD="gcloud run deploy $SERVICE_NAME \
  --image $IMAGE_NAME \
  --platform managed \
  --region $REGION \
  --port $PORT \
  --cpu $CPU \
  --memory $MEMORY \
  --min-instances $MIN_INSTANCES \
  --max-instances $MAX_INSTANCES \
  --concurrency $CONCURRENCY \
  --timeout $TIMEOUT \
  --ingress $INGRESS"

# Add optional parameters
if [ ! -z "$ENV_VARS" ]; then
  CMD="$CMD --set-env-vars=\"$ENV_VARS\""
fi

if [ ! -z "$CLOUDSQL_INSTANCES" ]; then
  CMD="$CMD --set-cloudsql-instances=$CLOUDSQL_INSTANCES"
fi

if [ ! -z "$VPC_CONNECTOR" ]; then
  CMD="$CMD --vpc-connector $VPC_CONNECTOR"
fi

if [ ! -z "$SERVICE_ACCOUNT" ]; then
  CMD="$CMD --service-account $SERVICE_ACCOUNT"
fi

if [ "$AUTHENTICATE" != true ]; then
  CMD="$CMD --allow-unauthenticated"
fi

# Deploy to Cloud Run
echo "Deploying to Google Cloud Run..."
echo "Running command: $CMD"
eval "$CMD"

echo ""
echo "Deployment complete!"
echo "Your application should now be available at the Cloud Run URL shown above."
echo ""
echo "To view your service details, run:"
echo "gcloud run services describe $SERVICE_NAME --region $REGION"
