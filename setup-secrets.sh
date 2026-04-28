#!/bin/bash
# Setup secrets in Google Cloud Secret Manager for Cloud Build
# Usage: ./setup-secrets.sh <GOOGLE_API_KEY> <GOOGLE_GENERATIVE_AI_API_KEY>

if [ $# -ne 2 ]; then
    echo "Usage: $0 <GOOGLE_API_KEY> <GOOGLE_GENERATIVE_AI_API_KEY>"
    echo ""
    echo "Example:"
    echo "  $0 'AIzaSy...' 'AQ.Ab8R...'"
    exit 1
fi

GOOGLE_API_KEY=$1
GOOGLE_GENAI_KEY=$2
PROJECT_ID="caresync-vertex"

echo "Setting up secrets in Google Cloud Secret Manager..."
echo "Project: $PROJECT_ID"
echo ""

# Create GOOGLE_API_KEY secret
echo "Creating GOOGLE_API_KEY secret..."
echo -n "$GOOGLE_API_KEY" | gcloud secrets create GOOGLE_API_KEY --data-file=- --project=$PROJECT_ID 2>/dev/null || \
gcloud secrets versions add GOOGLE_API_KEY --data-file=<(echo -n "$GOOGLE_API_KEY") --project=$PROJECT_ID

# Create GOOGLE_GENERATIVE_AI_API_KEY secret
echo "Creating GOOGLE_GENERATIVE_AI_API_KEY secret..."
echo -n "$GOOGLE_GENAI_KEY" | gcloud secrets create GOOGLE_GENERATIVE_AI_API_KEY --data-file=- --project=$PROJECT_ID 2>/dev/null || \
gcloud secrets versions add GOOGLE_GENERATIVE_AI_API_KEY --data-file=<(echo -n "$GOOGLE_GENAI_KEY") --project=$PROJECT_ID

echo ""
echo "✅ Secrets created successfully!"
echo ""
echo "Granting Cloud Build service account access to secrets..."

# Get Cloud Build service account
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')
CLOUD_BUILD_SA="${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com"

# Grant secret accessor role
gcloud secrets add-iam-policy-binding GOOGLE_API_KEY \
  --member=serviceAccount:$CLOUD_BUILD_SA \
  --role=roles/secretmanager.secretAccessor \
  --project=$PROJECT_ID

gcloud secrets add-iam-policy-binding GOOGLE_GENERATIVE_AI_API_KEY \
  --member=serviceAccount:$CLOUD_BUILD_SA \
  --role=roles/secretmanager.secretAccessor \
  --project=$PROJECT_ID

echo ""
echo "✅ IAM permissions granted!"
echo ""
echo "Next steps:"
echo "1. Push this code to GitHub: git push origin main"
echo "2. Cloud Build will automatically deploy with the secrets"
