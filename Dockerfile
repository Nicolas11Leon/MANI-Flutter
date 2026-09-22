# Multi-stage Dockerfile for Flutter Web

# Stage 1: Build Flutter Web
FROM ghcr.io/cirruslabs/flutter:stable AS builder

WORKDIR /app

# Copy dependency configuration files first for Docker layer caching
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copy all source files
COPY . .

# Usar el .env real (incluido en el build context para dev).
# En CI/CD se inyecta via ARG o secret antes de este paso.
RUN if [ ! -f .env ]; then cp .env.example .env 2>/dev/null || touch .env; fi

# Build web in release mode
RUN flutter build web --release

# Stage 2: Serve with lightweight Nginx
FROM nginx:alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /app/build/web /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
