# Stage 1: Build Flutter web
FROM ghcr.io/cirruslabs/flutter:latest as builder

# Install Node.js for Firebase CLI
RUN curl -sL https://deb.nodesource.com/setup_18.x | bash - && apt-get install -y nodejs

# Set working directory
WORKDIR /app

# Copy pubspec files
COPY pubspec.yaml pubspec.lock ./

# Get dependencies
RUN flutter pub get

# Install Firebase CLI and FlutterFire CLI
RUN npm install -g firebase-tools
RUN dart pub global activate flutterfire_cli

# Copy all source files
COPY . .

# Generate Firebase configuration
# For local development, this will prompt for authentication
# For Cloud Build, ensure .firebaserc and service account are available
RUN --mount=type=secret,id=firebase_token \
    if [ -f /run/secrets/firebase_token ]; then \
      export FIREBASE_TOKEN=$(cat /run/secrets/firebase_token); \
      flutterfire configure --project=caresync-vertex --force --platforms=web,android,ios,windows || true; \
    else \
      echo "Warning: No Firebase token provided. Skipping flutterfire configure."; \
      echo "Ensure lib/firebase_options.dart exists locally before building."; \
    fi

# Build web
RUN flutter build web --release

# Stage 2: Serve with Nginx
FROM nginx:alpine

# Copy built files from builder stage
COPY --from=builder /app/build/web /usr/share/nginx/html

# Copy nginx config
COPY nginx.conf /etc/nginx/nginx.conf

# Expose port 8080
EXPOSE 8080

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
