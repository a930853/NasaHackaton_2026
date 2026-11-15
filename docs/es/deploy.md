# Despliegue

El despliegue principal es **en Internet con Coolify** (un VPS con dominio). En local, con el mismo `compose.yaml` y un *override*, se puede desplegar **el juego** o **la pantalla de depuración**.

| | Orden | `/game/` sirve | HTTPS |
|---|---|---|---|
| **Internet** (principal) | Coolify con `compose.yaml` | `dist/game` (el juego) | Traefik de Coolify, Let's Encrypt |
| Local | `npm run docker:local` | `dist/game` (el juego) | Servicio `tls`, certificado autofirmado |
| Local, desarrollo | `npm run docker:dev` | `dist/game_debug` (depuración) + log de mensajes | Servicio `tls`, certificado autofirmado |

Antes hay que **exportar a web** el proyecto que se sirve: abrir `game/` o `game_debug/` en Godot → **Proyecto → Exportar → Web**. Las dos exportaciones se versionan en `dist/`. Si falta, la imagen no se construye y lo dice.

> Para programar sigue siendo más cómodo `npm run dev` (sin Docker, recarga al momento).

## Cómo encaja

Godot 4 **no arranca en web sin un contexto seguro** (HTTPS o `localhost`), así que siempre hay un proxy con HTTPS delante. La app es la misma en los dos casos; solo cambia quién pone el HTTPS:

```text
Internet:  navegador ──https──> Traefik (Coolify) ──http──> web (Nginx :80) ──> backend (:3000)
Local:     navegador ──https──> tls (Nginx :443)   ──http──> web (Nginx :80) ──> backend (:3000)
```

- **`web`** sirve siempre HTTP en el puerto 80: landing, mando, Godot y el proxy de `/ws` y `/api` al backend. No sabe nada de certificados.
- **`tls`** (solo en local) hace lo mismo que Traefik: cifra con un certificado autofirmado y reenvía todo, WebSocket incluido, a `web`.

Todo sale del mismo origen, así que la pantalla y los móviles construyen la URL del WebSocket con `location` (`wss://<host>/ws`): nada de IPs ni dominios en el código.

## Internet con Coolify

1. **DNS**: un registro `A` del dominio (p. ej. `marte.example.com`) a la IP del VPS.
2. En Coolify: **+ New → Resource → Public/Private Repository** con este repositorio y la rama `main`.
3. **Build Pack: Docker Compose**, y en *Docker Compose Location* `/compose.yaml`.
4. En el servicio **`web`**, el dominio con `https://`: `https://marte.example.com`. El `backend` se deja sin dominio (solo se llega a él a través de `web`).
5. **Deploy**. La primera vez tarda (compila el mando y la landing dentro de la imagen) y Traefik pide el certificado.

Direcciones: la pantalla en `https://marte.example.com/game/` y los móviles en `https://marte.example.com/` con el código de sala, **desde cualquier red**. Como el certificado es de verdad, ningún navegador avisa.

`compose.yaml` no publica puertos (el 80 y el 443 del VPS son de Traefik) y tiene *healthchecks* en los dos servicios para que Coolify sepa cuándo está listo.

A tener en cuenta:

- **Coolify construye desde Git**: sirve el `dist/game/` que esté subido. Después de cambiar `game/` hay que exportar y subir `dist/game/` antes de redesplegar.
- **Las salas viven en memoria**: un redespliegue o reinicio del backend corta las partidas en curso. Mejor no redesplegar durante una demo.
- **Está abierto a Internet**: cualquiera con la dirección puede crear una sala. El código de sala no es una credencial, pero sin él no se entra en una partida ajena. El backend rechaza mensajes de más de 64 KB.

## En local

```bash
npm run docker:local   # el juego
npm run docker:dev     # la pantalla de depuración, con los mensajes en `docker compose logs -f backend`
```

| Quién | Dirección |
|---|---|
| Pantalla (proyector) | `https://<IP-del-PC>/game/` |
| Móviles (misma Wi-Fi) | `https://<IP-del-PC>/` con el código, o `https://<IP-del-PC>/controller/?room=<código>` |

Abrid la pantalla con la **IP de la LAN**, no con `localhost`: con `localhost` funciona, pero la dirección del mando que enseña no les sirve a los móviles.

El certificado es **autofirmado**: lo genera el servicio `tls` la primera vez y se guarda en el volumen `certs`, así que no cambia al reiniciar. **Cada navegador avisa la primera vez** («conexión no privada») y hay que pulsar *Configuración avanzada → Continuar*, también en los móviles. Para quitar el aviso, dejad un `cert.pem` y un `key.pem` propios (p. ej. de [mkcert](https://github.com/FiloSottile/mkcert)) en ese volumen.

Godot de **escritorio** (el editor) no puede conectarse a este despliegue porque rechaza el certificado autofirmado. Desde el editor se usa `npm run dev`.

## Piezas

```text
compose.yaml            Internet (Coolify): backend + web, sin puertos publicados, healthchecks
compose.local.yaml      local: añade el servicio tls en los puertos 80 y 443
compose.dev.yaml        local, desarrollo: GAME_EXPORT=game_debug y LOG_MESSAGES=1
deploy/web.Dockerfile   compila el mando y la landing (Vite) y copia dist/<GAME_EXPORT>/
deploy/nginx/default.conf  Nginx de la app (HTTP): rutas y proxy de /ws y /api
deploy/tls/             proxy HTTPS de local: Dockerfile, nginx.conf y 15-cert.sh (certificado)
.dockerignore           deja fuera node_modules, .godot, los proyectos de Godot…
```

Rutas de la app:

| Ruta | Qué hace |
|---|---|
| `/` | La landing (compilada de `landing/`) |
| `/game/` | Exportación de Godot, sin caché (cada exportación reutiliza los nombres de fichero) |
| `/controller/…` | Mando; las rutas de rol caen en `index.html` |
| `/ws` | Proxy WebSocket al backend (tiempo de espera 1 h) |
| `/api/` | Proxy HTTP al backend |

El `.wasm` y el JavaScript se sirven comprimidos (el `.wasm` de Godot pasa de ~39 MB a ~12 MB).

## Problemas habituales

| Síntoma | Causa |
|---|---|
| «Secure Context - Check web server configuration (use HTTPS)» | Se abrió `/game/` por `http://`. Usad `https://`. |
| «La sala no existe» | El mando está hablando con otro backend (p. ej. un `npm run dev` abierto a la vez en `:5173`). Abrid el mando desde la misma dirección que la pantalla. |
| En local, el puerto 80 o 443 está ocupado | `HTTP_PORT=8080 HTTPS_PORT=8443 npm run docker:local` y entrad con `https://<IP>:8443/`. |
| En local, el móvil no carga | Misma Wi-Fi que el PC y cortafuegos de Windows abierto para Docker en los puertos 80 y 443. |
| En Coolify, «Bad Gateway» o sin certificado | El dominio tiene que estar en el servicio `web` (no en `backend`) y el DNS apuntando ya al VPS. |
