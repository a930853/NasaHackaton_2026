# Imagen "web": Nginx con todo lo estático y el proxy hacia el backend.
#
#   /             landing/
#   /controller/  el mando, compilado aquí mismo (no hace falta npm run build antes)
#   /game/        la exportación web de Godot elegida con GAME_EXPORT
#
# GAME_EXPORT=game        producción (compose.yaml)
# GAME_EXPORT=game_debug  desarrollo (compose.dev.yaml)
#
# Se construye desde la raíz del repo (context: .).

# ---------- 1. Compilar el mando ----------
FROM node:22-bookworm-slim AS controller
WORKDIR /src/controller
COPY controller/package.json controller/package-lock.json ./
RUN npm ci
COPY controller/ ./
# vite.config.js compila a ../dist/controller → /src/dist/controller
RUN npm run build

# ---------- 2. Nginx ----------
FROM nginx:1.27-alpine
ARG GAME_EXPORT=game

# openssl para generar el certificado autofirmado al arrancar (15-cert.sh)
RUN apk add --no-cache openssl

COPY deploy/nginx/default.conf /etc/nginx/conf.d/default.conf
COPY deploy/nginx/15-cert.sh /docker-entrypoint.d/
# Por si Git en Windows lo dejó con finales CRLF (sh no lo entendería).
RUN sed -i 's/\r$//' /docker-entrypoint.d/15-cert.sh && chmod +x /docker-entrypoint.d/15-cert.sh

COPY landing/ /srv/www/
COPY --from=controller /src/dist/controller/ /srv/www/controller/
COPY dist/${GAME_EXPORT}/ /srv/www/game/

# Fallar al construir (y no al abrir el navegador) si falta la exportación.
RUN test -f /srv/www/game/index.html || { \
      echo "Falta dist/${GAME_EXPORT}/index.html: exporta ${GAME_EXPORT} desde Godot (preset Web) antes de construir."; \
      exit 1; }
