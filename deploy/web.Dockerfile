# Imagen "web": Nginx con todo lo estático y el proxy hacia el backend.
#
#   /             la landing, compilada aquí mismo (Vue + Vite)
#   /controller/  el mando, compilado aquí mismo (no hace falta npm run build antes)
#   /game/        la exportación web de Godot elegida con GAME_EXPORT
#
# Sirve HTTP en el 80; el HTTPS lo pone el proxy de delante (Traefik o deploy/tls).
#
# GAME_EXPORT=game        el juego (compose.yaml)
# GAME_EXPORT=game_debug  pantalla de depuración (compose.dev.yaml)
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

# ---------- 2. Compilar la landing ----------
FROM node:22-bookworm-slim AS landing
WORKDIR /src/landing
COPY landing/package.json landing/package-lock.json ./
RUN npm ci
COPY landing/ ./
# vite.config.js compila a ../dist/landing → /src/dist/landing
RUN npm run build

# ---------- 3. Nginx ----------
FROM nginx:1.27-alpine
ARG GAME_EXPORT=game

COPY deploy/nginx/default.conf /etc/nginx/conf.d/default.conf

COPY --from=landing /src/dist/landing/ /srv/www/
COPY --from=controller /src/dist/controller/ /srv/www/controller/
COPY dist/${GAME_EXPORT}/ /srv/www/game/

# Fallar al construir (y no al abrir el navegador) si falta la exportación.
RUN test -f /srv/www/game/index.html || { \
      echo "Falta dist/${GAME_EXPORT}/index.html: exporta ${GAME_EXPORT} desde Godot (preset Web) antes de construir."; \
      exit 1; }
