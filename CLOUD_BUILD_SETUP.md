# Cloud Build & Docker Configuration

This document explains how to set up Cloud Build with Firebase configuration generation.

## Problem
The Dockerfile needs to generate `lib/firebase_options.dart` during the build process, which requires Firebase authentication. The file is not committed to git for security reasons (see [FIREBASE_SETUP.md](FIREBASE_SETUP.md)).

## Solutions

### Option 1: Commit Firebase Config Locally (Recommended for CI/CD)

If you want Cloud Build to work seamlessly:

1. **Generate config locally** (already done):
   ```bash
   flutterfire configure --project=caresync-vertex
   ```

2. **Temporarily add to git** for this build only:
   ```bash
   git add lib/firebase_options.dart android/app/google-services.json
   git commit -m "Add Firebase config for Cloud Build"
   git push origin main
   ```

3. **Then remove from .gitignore tracking** if you want to keep it (not recommended for public repos with shared credentials)

### Option 2: Use Firebase CLI Token in Cloud Build (Recommended for Production)

1. **Generate a Firebase CLI token locally**:
   ```bash
   firebase login:ci
   ```
   This will output a long token. Save it.

2. **Store token in Google Cloud Secret Manager**:
   ```bash
   echo "YOUR_FIREBASE_TOKEN" | gcloud secrets create firebase-token --data-file=-
   ```

3. **Update cloudbuild.yaml** to use the secret:
   ```yaml
   steps:
     - name: 'gcr.io/cloud-builders/docker'
       secretEnv: ['FIREBASE_TOKEN']
       args:
         - 'build'
         - '--secret'
         - 'id=firebase_token,env=FIREBASE_TOKEN'
         - '-t'
         - 'gcr.io/$PROJECT_ID/elderly-ai-care-app:latest'
         - '.'
   
   secrets:
     - versionName: projects/$PROJECT_ID/secrets/firebase-token/versions/latest
       env: 'FIREBASE_TOKEN'
   ```

4. **Grant Cloud Build access to the secret**:
   ```bash
   gcloud secrets add-iam-policy-binding firebase-token \
     --member=serviceAccount:PROJECT_NUMBER@cloudbuild.gserviceaccount.com \
     --role=roles/secretmanager.secretAccessor
   ```

### Option 3: Use Service Account Key (Advanced)

For more control, use a Firebase service account:

1. Go to [Firebase Console](https://console.firebase.google.com) → Project Settings → Service Accounts
2. Download JSON key file
3. Store in Cloud Secret Manager as a file
4. Reference in Dockerfile/cloudbuild.yaml

## Current Setup

The Dockerfile currently expects `firebase_token` as a Docker build secret. The Dockerfile will:
- ✅ Skip build if no token is provided (won't fail the build)
- ✅ Generate config automatically if token is available
- ❌ Fail compilation if config not found

To make builds succeed, you need to either:
1. Commit Firebase config to repo (simple, but not ideal for security)
2. Set up Cloud Build secrets (recommended for production)

## Testing Locally

To test the Docker build locally:

```bash
# Option A: With local Firebase config
docker build -t elderly-ai-care-app:test .

# Option B: With Firebase token mounted
docker build \
  --secret id=firebase_token,env=FIREBASE_TOKEN \
  -t elderly-ai-care-app:test .
```

## Next Steps

Choose Option 1 or 2 above and let me know if you need help implementing it!
