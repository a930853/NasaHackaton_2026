# Despliegue en la LAN

Todo se levanta con Docker Compose en el PC que hace de servidor. Desarrollo y producción son **el mismo despliegue**; solo cambia qué exportación de Godot se sirve en `/game/`.

| | Orden | `/game/` sirve | Log de mensajes |
|---|---|---|---|
| Desarrollo | `npm run docker:dev` | `dist/game_debug` (pantalla de depuración) | Sí |
| Producción | `npm run docker:prod` | `dist/game` (el juego) | No |

Antes hay que **exportar a web** el proyecto que se vaya a servir: abrir `game/` o `game_debug/` en Godot → **Proyecto → Exportar → Web**. Si falta la exportación, la imagen no se construye y lo dice.

> Para programar sigue siendo más cómodo `npm run dev` (sin Docker, recarga al momento). Docker sirve para probar el despliegue tal cual quedará.

## Por qué todo va por HTTPS

Godot 4 **no arranca en web sin un contexto seguro**: HTTPS o `localhost`. Por eso Nginx hace de **proxy inverso con HTTPS** para todo (pantalla, mando, landing y WebSocket `wss://`). El backend no cambia: Nginx descifra y le habla por HTTP dentro de la red de Docker. El puerto 80 solo redirige a HTTPS.

En una LAN sin dominio el certificado es **autofirmado**: lo genera el contenedor la primera vez y se guarda en el volumen `certs`, así que no cambia al reiniciar. **Cada navegador avisa la primera vez** («conexión no privada») y hay que pulsar *Configuración avanzada → Continuar*, también en los móviles.

Para quitar el aviso habría que usar un certificado de una autoridad propia (p. ej. [mkcert](https://github.com/FiloSottile/mkcert)) e instalar esa autoridad en cada dispositivo. Basta con dejar `cert.pem` y `key.pem` en el volumen `certs`; para una demo no suele compensar.

## Direcciones

| Quién | Dirección |
|---|---|
| Pantalla (proyector) | `https://<IP-del-PC>/game/` |
| Móviles | `https://<IP-del-PC>/controller/?room=<código>` (o el QR) |
| Inicio | `https://<IP-del-PC>/` |

Abrid la pantalla con la **IP de la LAN**, no con `localhost`. Con `localhost` funciona, pero la dirección del mando que se enseña no les sirve a los móviles (la pantalla de depuración lo avisa en rojo).

Godot de **escritorio** (el editor) no puede conectarse a este despliegue porque rechaza el certificado autofirmado. Desde el editor se usa `npm run dev`.

## Piezas

```text
compose.yaml            backend (sin puertos publicados) + web (Nginx, 80 y 443)
compose.dev.yaml        cambia GAME_EXPORT a game_debug y activa LOG_MESSAGES
deploy/web.Dockerfile   compila el mando y copia landing/, el mando y dist/<GAME_EXPORT>/
deploy/nginx/default.conf  HTTPS, rutas y proxy de /ws y /api
deploy/nginx/15-cert.sh    genera el certificado autofirmado si no existe
.dockerignore           deja fuera node_modules, .godot, los proyectos de Godot…
```

Rutas de Nginx:

| Ruta | Qué hace |
|---|---|
| `/` | `landing/` |
| `/game/` | Exportación de Godot, sin caché (cada exportación reutiliza los nombres de fichero) |
| `/controller/…` | Mando; las rutas de rol caen en `index.html` |
| `/ws` | Proxy WebSocket al backend (tiempo de espera 1 h) |
| `/api/` | Proxy HTTP al backend |

El `.wasm` y el JavaScript se sirven comprimidos (el `.wasm` de Godot pasa de ~39 MB a ~12 MB).

## Problemas habituales

| Síntoma | Causa |
|---|---|
| «Secure Context - Check web server configuration (use HTTPS)» | Se abrió `/game/` por `http://<IP>`. Usad `https://`. |
| «La sala no existe» | El mando está hablando con otro backend (p. ej. un `npm run dev` abierto a la vez en `:5173`). Abrid el mando desde la misma dirección que la pantalla. |
| El puerto 80 o 443 está ocupado | `HTTP_PORT=8080 HTTPS_PORT=8443 npm run docker:dev` y entrad con `https://<IP>:8443/`. |
| El móvil no carga | Misma Wi-Fi que el PC y cortafuegos de Windows abierto para Docker en los puertos 80 y 443. |

Ver los mensajes en bruto (desarrollo): `docker compose logs -f backend`.
