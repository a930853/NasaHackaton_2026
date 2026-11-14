# Documentación

## Qué leer según lo que vayas a hacer

| Si vas a… | Lee |
|---|---|
| Entender el juego o diseñar eventos | [juego/diseno.md](juego/diseno.md) → [juego/eventos.md](juego/eventos.md) |
| Programar la lógica del juego en Godot | [godot/arquitectura.md](godot/arquitectura.md) |
| Conectar Godot con los móviles | [protocol.md](protocol.md) → [godot/red.md](godot/red.md) |
| Tocar el mando web | [protocol.md](protocol.md) → [controller.md](controller.md) |
| Tocar el backend | [protocol.md](protocol.md) → [backend.md](backend.md) |
| Desplegar con Docker | [deploy.md](deploy.md) |

## Documentos

```text
docs/
  protocol.md          Contrato de mensajes entre Godot, mandos y backend. FUENTE DE VERDAD de la red.
  backend.md           Servidor Node: estructura, modelo de sala, reconexión, log de mensajes
  controller.md        Mando web (Vue): rutas de rol y NFC, estados, recuperación de sesión, estilos
  deploy.md            Docker Compose, HTTPS en Nginx, desarrollo frente a producción
  juego/
    diseno.md          Reglas: bucle de un Sol, roles, recursos, objetivos, APIs y decisiones pendientes
    eventos.md         Catálogo de eventos con sus opciones, efectos y fuentes de la NASA
  godot/
    arquitectura.md    Gestores, máquina de estados, modelos y formato de events.json
    red.md             Autoload Net: sala, lobby, QR, envío de vistas y validación de elecciones
```

## Fuentes de verdad

- **Mensajes de red:** [protocol.md](protocol.md). Cualquier cambio se acuerda ahí primero.
- **Cifras de los eventos y reglas numéricas:** [`game/Data/events.json`](../game/Data/events.json). Los documentos de `juego/` lo explican; si no coinciden, manda el JSON.
- **Lo que está sin decidir:** [juego/diseno.md#decisiones-pendientes](juego/diseno.md#decisiones-pendientes).
