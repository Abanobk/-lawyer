# syntax=docker/dockerfile:1
# بناء من جذر الريبو: docker build -f infra/web/Dockerfile .
FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app

COPY app/pubspec.yaml app/pubspec.lock* ./
RUN flutter pub get

COPY app/ ./

# نفس أصل الصفحة + /api (مناسب لأي دومين أو منفذ أمام Nginx)
ARG API_BASE_URL=/api
RUN flutter build web --release \
    --dart-define=API_BASE_URL=${API_BASE_URL}

FROM nginx:1.27-alpine
COPY infra/web/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html
