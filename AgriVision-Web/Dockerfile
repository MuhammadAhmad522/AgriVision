# Stage 1: Build the React Application
FROM node:22-alpine AS builder

# Set working directory
WORKDIR /app

# Copy package files for dependency installation
COPY package.json package-lock.json ./

# Install dependencies using clean install for reproducible builds
RUN npm ci

# Copy the rest of the application code
COPY . .

# Build the application for production
# VITE_API_URL is intentionally left blank so the client uses relative paths (/api/...)
# which will be caught and proxied by the NGINX reverse proxy.
ENV VITE_API_URL=""
RUN npm run build


# Stage 2: Serve the static files with NGINX
FROM nginx:alpine

# Remove default nginx static assets
RUN rm -rf /usr/share/nginx/html/*

# Copy static assets from builder stage
COPY --from=builder /app/dist /usr/share/nginx/html

# Copy custom NGINX configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port 80
EXPOSE 80

# Start NGINX
CMD ["nginx", "-g", "daemon off;"]
