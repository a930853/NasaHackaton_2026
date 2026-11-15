# Documentación (español)

[English](README_EN.md) · **Español**

Documentación de **Red Planet Survivors**, un juego cooperativo de supervivencia en Marte para el NASA Hackathon 2026. La versión en inglés está en [`en/`](README_EN.md); la portada del proyecto es el [README de la raíz](../README.md).

**¿Primera vez?** Empieza por el [resumen del proyecto](es/resumen.md): en una sola página cuenta qué es el juego, cómo se juega, todos los eventos y qué datos de la NASA usa.

## Recorrido rápido

1. **Juégalo:** <https://red-planet-survivors.karu.es/> (ábrelo en un ordenador y únete desde los móviles).
2. **Míralo:** [vídeo promocional de 20 segundos](assets/promo-video.mp4).
3. **La idea:** [propuesta original](proposal/proposal-es.pdf) (PDF).
4. **El juego:** [resumen del proyecto](es/resumen.md).
5. **Datos de la NASA:** [resumen › Fuentes de datos](es/resumen.md#9-fuentes-de-datos).
6. **Cómo está hecho:** [protocolo de mensajes](es/protocol.md) y después la guía de cada pieza (abajo).

## Qué leer según lo que busques

| Si quieres… | Lee |
|---|---|
| Saber qué es el juego y cómo se juega | [resumen.md](es/resumen.md) |
| Ver qué datos reales de la NASA usa | [resumen.md › Fuentes de datos](es/resumen.md#9-fuentes-de-datos) |
| Entender las reglas y por qué son así | [juego/diseno.md](es/juego/diseno.md) |
| Ver cómo se comunican Godot, el servidor y los móviles | [protocol.md](es/protocol.md) → [godot/red.md](es/godot/red.md) |
| Programar la lógica del juego en Godot | [godot/arquitectura.md](es/godot/arquitectura.md) |
| Tocar el mando web | [protocol.md](es/protocol.md) → [controller.md](es/controller.md) |
| Tocar el backend | [protocol.md](es/protocol.md) → [backend.md](es/backend.md) |
| Desplegarlo (Internet o local) | [deploy.md](es/deploy.md) |

## Documentos

```text
docs/
  README_ES.md         Esta página
  README_EN.md         El mismo índice en inglés
  es/
    resumen.md           Resumen de la versión entregada: juego, eventos, ayuda de la Tierra, glosario y fuentes de datos
    protocol.md          Contrato de mensajes entre Godot, mandos y backend. FUENTE DE VERDAD de la red.
    backend.md           Servidor Node: estructura, modelo de sala, reconexión, log de mensajes
    controller.md        Mando web (Vue): rutas de rol y NFC, estados, recuperación de sesión, estilos
    deploy.md            Internet con Coolify y despliegue en local con Docker
    juego/
      diseno.md          Reglas: bucle de un Sol, roles, recursos, equilibrio, objetivos y decisiones de diseño
      eventos.md         Catálogo de eventos del diseño original, con sus fuentes de la NASA
      tiempos_fuera.md   Tripulación ocupada: cuántos Sols tarda cada tarea y qué pasa si la base se queda vacía
    godot/
      arquitectura.md    Gestores, máquina de estados, modelos y formato de events.json
      red.md             Autoload Net: sala, lobby, QR, envío de vistas y validación de elecciones
  en/                  Documentación en inglés (misma estructura)
  assets/              Boceto de la interfaz y vídeo promocional
  proposal/            Propuesta original del hackathon (PDF, en español y en inglés)
```

## Fuentes de verdad

- **Mensajes de red:** [protocol.md](es/protocol.md). Cualquier cambio se acuerda ahí primero.
- **Cifras de los eventos y reglas numéricas:** [`game/Data/events.json`](../game/Data/events.json) y las constantes de `game/Scripts/game_state.gd`. Los documentos lo explican; si no coinciden, manda el código.
- **Decisiones que se tomaron al unir los documentos de partida:** [juego/diseno.md › Decisiones de diseño](es/juego/diseno.md#decisiones-de-diseño).
- Los documentos en español son los originales; si alguna vez no coinciden con los ingleses, mandan el español y el código.
