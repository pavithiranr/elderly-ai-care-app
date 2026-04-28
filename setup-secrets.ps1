# Setup secrets in Google Cloud Secret Manager for Cloud Build (PowerShell)
# Usage: .\setup-secrets.ps1 -GoogleApiKey "AIzaSy..." -GoogleGenAiKey "AQ.Ab8R..."

param(
    [Parameter(Mandatory=$true)]
    [string]$GoogleApiKey,
    
    [Parameter(Mandatory=$true)]
    [string]$GoogleGenAiKey
)

$PROJECT_ID = "caresync-vertex"

Write-Host "Setting up secrets in Google Cloud Secret Manager..." -ForegroundColor Green
Write-Host "Project: $PROJECT_ID" -ForegroundColor Cyan
Write-Host ""

# Create GOOGLE_API_KEY secret
Write-Host "Creating GOOGLE_API_KEY secret..." -ForegroundColor Yellow
try {
    $GoogleApiKey | gcloud secrets create GOOGLE_API_KEY --data-file=- --project=$PROJECT_ID 2>$null
} catch {
    $GoogleApiKey | gcloud secrets versions add GOOGLE_API_KEY --data-file=- --project=$PROJECT_ID
}

# Create GOOGLE_GENERATIVE_AI_API_KEY secret
Write-Host "Creating GOOGLE_GENERATIVE_AI_API_KEY secret..." -ForegroundColor Yellow
try {
    $GoogleGenAiKey | gcloud secrets create GOOGLE_GENERATIVE_AI_API_KEY --data-file=- --project=$PROJECT_ID 2>$null
} catch {
    $GoogleGenAiKey | gcloud secrets versions add GOOGLE_GENERATIVE_AI_API_KEY --data-file=- --project=$PROJECT_ID
}

Write-Host ""
Write-Host "✅ Secrets created successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Granting Cloud Build service account access to secrets..." -ForegroundColor Yellow

# Get project number
$PROJECT_NUMBER = gcloud projects describe $PROJECT_ID --format='value(projectNumber)'
$CLOUD_BUILD_SA = "$PROJECT_NUMBER@cloudbuild.gserviceaccount.com"

# Grant secret accessor role
gcloud secrets add-iam-policy-binding GOOGLE_API_KEY `
  --member=serviceAccount:$CLOUD_BUILD_SA `
  --role=roles/secretmanager.secretAccessor `
  --project=$PROJECT_ID

gcloud secrets add-iam-policy-binding GOOGLE_GENERATIVE_AI_API_KEY `
  --member=serviceAccount:$CLOUD_BUILD_SA `
  --role=roles/secretmanager.secretAccessor `
  --project=$PROJECT_ID

Write-Host ""
Write-Host "✅ IAM permissions granted!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Push this code to GitHub: git push origin main"
Write-Host "2. Cloud Build will automatically deploy with the secrets"
