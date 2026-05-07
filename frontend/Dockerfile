# Stage 1: Build Flutter Web App
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app
COPY . .

# Get packages and build for web
RUN flutter pub get
RUN flutter build web

# Stage 2: Serve with Nginx
FROM nginx:alpine

# Copy built assets from the previous stage
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
