# Use pre-built Flutter web files
FROM nginx:alpine

# Copy the pre-built Flutter web files
COPY build/web /usr/share/nginx/html

# Copy nginx config
COPY nginx.conf /etc/nginx/nginx.conf

# Expose port 8080
EXPOSE 8080

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
