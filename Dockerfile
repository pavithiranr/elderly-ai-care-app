# Stage 1: Build Flutter Web
FROM google/dart:latest AS builder
WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN dart pub get
COPY . .
RUN dart pub get --offline
RUN dart compile js -m -o build/web/main.dart.js lib/main.dart

# Stage 2: Serve with nginx
FROM nginx:alpine
COPY --from=builder /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]
