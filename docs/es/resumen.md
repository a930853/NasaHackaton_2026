# Resumen del proyecto: Red Planet Survivors

Resumen de lo que hay **implementado** hoy: cómo funciona el juego, todos los tipos de evento y de dónde salen los datos. Las cifras vienen de [`game/Data/events.json`](../../game/Data/events.json) y del código de `game/Scripts/`; si algo no coincide con este documento, manda el código.

> Para más detalle: reglas en [juego/diseno.md](juego/diseno.md), red en [godot/red.md](godot/red.md), mensajes en [protocol.md](protocol.md) y despliegue en [deploy.md](deploy.md).

## Índice

1. [Qué es](#1-qué-es)
2. [Piezas del proyecto](#2-piezas-del-proyecto)
3. [Cómo se juega](#3-cómo-se-juega)
4. [Tipos de evento](#4-tipos-de-evento)
5. [Cómo funciona un evento](#5-cómo-funciona-un-evento)
6. [Catálogo de eventos](#6-catálogo-de-eventos)
7. [Ayuda de la Tierra](#7-ayuda-de-la-tierra)
8. [Libro de palabras](#8-libro-de-palabras)
9. [Fuentes de datos](#9-fuentes-de-datos)

---

## 1. Qué es

Juego cooperativo y educativo para el NASA Hackathon 2026, pensado para **niños de 7 a 12 años** (textos en inglés sencillo). La tripulación acaba de aterrizar en el cráter Jezero y tiene que **sobrevivir 20 Sols** (días marcianos) en una base, resolviendo un problema cada Sol. Cada problema se basa en una misión o un dato real de la NASA.

- **Pantalla principal (Godot, exportada a web):** la cabina de la nave, con la ventana a Marte, la información del evento, las cuatro barras de recursos y la tripulación.
- **Móviles (mando web):** cada jugador entra con un código de sala, elige un rol y vota las opciones.
- **1 a 4 jugadores**, o una sola persona con el ratón.

## 2. Piezas del proyecto

| Pieza | Carpeta | Qué hace |
|---|---|---|
| Juego | `game/` (Godot 4.7, GDScript) | **Autoridad del juego**: eventos, reglas, recursos, validación y resolución de decisiones. |
| Backend | `backend/` (Node, `express` + `ws`) | **Autoridad de la sesión**: salas, jugadores, roles y reenvío de mensajes por un único WebSocket (`/ws`). |
| Mando | `controller/` (Vue 3 + Vite + Tailwind) | Pantalla del móvil. Solo envía la opción elegida; no calcula nada. |
| Inicio | `landing/` | Página `/`: crear partida o entrar con código. |
| Despliegue | `deploy/`, `compose.yaml` | Nginx sirve todo con Docker Compose: en Internet con Coolify (principal) o en la LAN con HTTPS autofirmado. |

Dentro de Godot, la lógica está repartida en *autoloads*:

| Autoload | Responsabilidad |
|---|---|
| `GameState` | Recursos, objetivos, Sol actual, tripulación ocupada, problemas activos y efectos diferidos. Único sitio que modifica recursos. |
| `EventManager` | Carga `events.json`, comprueba condiciones y enfriamientos, y elige el evento de cada Sol. |
| `TurnManager` | Máquina de estados del Sol, lectura, votación, cuenta atrás, ayuda de la Tierra y alerta solar. |
| `GlossaryManager` | Libro de palabras (`glossary.json`). |
| `Net` | WebSocket con el backend. |
| `PhoneBridge` | Envía a cada móvil su pantalla y valida cada voto que llega. |
| `Events` | Bus de señales entre sistemas. |

## 3. Cómo se juega

### Modos

Al pulsar **Start Game** se elige:

- **Play solo:** una persona, una pantalla. Las opciones salen bajo el evento y se eligen con el ratón. No usa red.
- **Play multiplayer:** se crea una sala; los móviles entran con el código, eligen rol y votan. Si el servidor no responde en 4 s, se ofrece jugar solo.

### Bucle de un Sol

```text
INICIO DEL SOL ─► SELECCIÓN DEL EVENTO ─► DECISIÓN ─► RESOLUCIÓN ─► FIN DEL SOL ─► (siguiente Sol o final)
```

| Fase | Qué pasa |
|---|---|
| Inicio del Sol | Vuelven los tripulantes que terminan su tarea. Cambios automáticos de las barras (oxígeno −3 hasta acabar MOXIE, energía +7 (+6 desde el Sol 8), base −2, y desde el Sol 4 salud −4). Se aplican los problemas activos y los efectos diferidos de hoy. |
| Selección | Se elige el evento del día (ver [orden de selección](#orden-de-selección)). Se desbloquean sus palabras del libro. |
| Decisión | Se lee el evento y se elige una opción (clic o votación). |
| Resolución | Se tira el éxito o fallo, se aplican los efectos y se muestra qué cambió. |
| Fin del Sol | Derrota si un recurso llega a 0. Victoria al llegar al Sol 20. |

### Recursos

Cuatro barras de 0 a 100 que empiezan en **80**. Si cualquiera llega a **0**, se pierde.

| Recurso | Id | Cambio automático cada Sol |
|---|---|---|
| Salud | `health` | −4 desde el Sol 4 (estrés y radiación) |
| Oxígeno | `oxygen` | −3 hasta que MOXIE está al 100 % |
| Energía | `energy` | +7 (paneles solares), +6 desde el Sol 8 (polvo) |
| Fuerza de la base | `integrity` | −2 (viento y polvo) |

Estas presiones reparten las derrotas entre las cuatro barras (ver [Equilibrio de la dificultad](juego/diseno.md#equilibrio-de-la-dificultad)): un jugador atento gana ~72 % de las partidas y, cuando pierde, suele ser por energía (~18 %) u oxígeno (~10 %); quien elige al azar gana ~21 %.

### Roles

| Id | Nombre en el juego | Color | Opciones propias en eventos |
|---|---|---|---|
| `engineer` | Engineer | Amarillo | Máquinas, paneles, rover, sensores, MOXIE, escudos |
| `biologist` | Biologist | Verde | Invernadero, probióticos, reparto de energía |
| `doctor` | Doctor | Rojo | Botiquín, juegos de memoria |
| `generalist` | Generalist en los avatares y los móviles; Commander en las tarjetas de opción | Blanco | Moral del equipo, apagar el laboratorio |

### Objetivos, victoria y puntuación

| Objetivo | Se cumple cuando | Qué da |
|---|---|---|
| Tripulación sana | La salud se mantiene siempre por encima de 50 | Puntos |
| Colonia estable | 3 cosechas | Puntos |
| Rescate del rover | El rover queda libre | Puntos |
| Red de sensores | 3 sensores colocados | Puntos. Si se completa **antes del Sol 13**, el terremoto avisa |
| MOXIE | Montaje al 100 % | Puntos. Deja de perderse oxígeno cada Sol |

- **Victoria:** llegar al Sol 20 con todos los recursos por encima de 0.
- **Derrota:** cualquier recurso a 0.
- **Puntuación:** 200 puntos por objetivo cumplido + la media de las cuatro barras.

---

## 4. Tipos de evento

Cada evento de `events.json` tiene un campo `kind` que decide cuándo puede salir.

| Tipo (`kind`) | Cuántos | Cuándo sale | Eventos |
|---|---|---|---|
| **Aleatorio** (`random`) | 5 | Cualquier Sol en que cumpla sus condiciones y haya pasado su enfriamiento. | Invernadero, dolor de barriga, tristeza espacial, rover atrapado, polvo en los paneles |
| **Objetivo** (`objective`) | 8 | Forman cadenas: cada uno exige que el anterior esté hecho. Tienen prioridad sobre los aleatorios. Los de MOXIE pesan el doble al elegir (`weight: 2`). | Sensores (fabricar, colocar, sensor con polvo), terremotos (con y sin aviso), MOXIE (fases 1, 2 y 3) |
| **Relleno** (`filler`) | 1 | Solo si no hay ningún otro evento posible. | Sol tranquilo |
| **Automático** (`auto`) | 1 | En cuanto se cumple su condición, antes que cualquier otro. | MOXIE funciona |
| **Tiempo real** (`realtime`) | 1 | Si la NASA registra una llamarada solar fuerte reciente. Una vez por partida. | Alerta de tormenta solar |

Además hay dos situaciones que no están en `events.json`:

- **Base vacía:** si al empezar un Sol los 4 tripulantes están ocupados, ese día no sale ningún evento. Se aplica el consumo diario y el día pasa.
- **Ayuda de la Tierra:** acción auxiliar sobre el evento del día (ver [sección 7](#7-ayuda-de-la-tierra)).

### Orden de selección

Cada Sol se elige un solo evento, en este orden:

1. **Alerta solar** pendiente (tiempo real).
2. **Evento en espera** cuya fecha ha llegado: la respuesta de la Tierra, o un problema que esperaba a que volviera alguien.
3. **Automático** que cumpla su condición.
4. **Programado** por una decisión anterior (por ejemplo, el terremoto con aviso).
5. **Objetivo o aleatorio:** si hay objetivos disponibles se elige uno con un 70 % de probabilidad; si no, un aleatorio.
6. **Relleno.**

### Condiciones y enfriamiento

- `conditions`: requisitos sobre el Sol (`min_sol`) y el estado (`state`, `state_gt`, `state_lt`, `any_of`). Ejemplo: «Tristeza espacial» sale desde el Sol 4, o antes si hay un dolor de barriga sin tratar.
- `cooldown_sols`: Sols que deben pasar para que se repita. 999 significa una sola vez.
- `scheduled_only`: el evento solo sale si otro lo programa.

---

## 5. Cómo funciona un evento

1. **Presentación.** Aparece el título y la ventana de Marte cambia según el evento (polvo, llamarada, temblor, oscuridad…). Los eventos marcados `important` (terremotos y alerta solar) ponen una exclamación sobre el botón EVENT.
2. **Lectura.** La descripción se escribe poco a poco (23 letras por segundo, entre 2,5 y 12 s). El tutorial de la intro también escribe cada página poco a poco, pero ahí se puede saltar con *Next*. Hasta que termina no se puede elegir, votar ni pedir ayuda. Al terminar salen el dato NASA y las opciones.
3. **Opciones.** Cada evento tiene de 1 a 3. Unas son de un rol (`role`) y otras de todos (`role: null`). Se enseña lo que cuesta cada una; la probabilidad de éxito no se enseña.
4. **Decisión.**
   - *Solo:* clic en una opción.
   - *Multijugador:* todos ven **todas** las opciones y vota cada jugador conectado y en la base. Gana la más votada. Empate → segunda votación entre las empatadas → si vuelve a empatar, decide el voto del Comandante (el primer jugador que entró).
5. **Cuenta atrás** (solo terremotos): 20 s desde que acaba la lectura. Si se acaba el tiempo gana lo más votado, o la opción por defecto.
6. **Resolución.** Se tira el éxito con `success_chance`:
   - **Éxito:** se aplican todos los efectos y el progreso.
   - **Fallo:** se pagan igualmente los costes (efectos negativos), se pierden las recompensas y puede haber un castigo extra (`on_fail`). Si el evento tiene `retry_on_fail`, vuelve a salir para intentarlo otra vez.
7. **Ocupación.** Quien hace la tarea queda ocupado 0, 1 o 2 Sols (`away_sols`), haya salido bien o mal. Si la opción es de todos y tiene ocupación, sale **toda la tripulación** y solo se puede elegir si los 4 están en la base. Las opciones de un rol ocupado salen bloqueadas.

### Mecánicas disponibles en `events.json`

| Mecánica | Campo | Ejemplo |
|---|---|---|
| Efecto inmediato | `effects` | Energía −15, Oxígeno +10 |
| Efecto diferido | `delayed` | Comerse los brotes: Oxígeno −10 al Sol siguiente |
| Problema de varios Sols | `start_condition` (`daily` o `sequence`) | Tormenta de polvo: Energía −10 durante 2 Sols |
| Azar extra | `chance` | 50 % de encontrar una roca especial: Energía +10 |
| Progreso de objetivo | `set`, `add` | MOXIE al 33 %, +1 cosecha |
| Castigo al fallar | `on_fail` | El refuerzo falla: Fuerza de la base −10 |
| Reintento | `retry_on_fail` | Rover, sensores y MOXIE |
| Evento encadenado | `schedule_event` | Montar con cinta provoca «El sensor con polvo» 1–2 Sols después |
| Efecto al aparecer | `on_start` | Terremoto sin aviso: Fuerza de la base −20 antes de decidir |
| Cuenta atrás | `timer_seconds`, `timeout_option` | Terremotos: 20 s |
| Ocupación | `away_sols`, `away_all` | El ingeniero, ocupado 2 Sols |
| Peso al elegir | `weight` | Los eventos de MOXIE salen el doble de a menudo entre los objetivos |

---

## 6. Catálogo de eventos

Leyenda: **Quién** = rol dueño de la opción (*Todos* = opción general). **Éxito** = probabilidad interna, que el jugador no ve. **Ocupa** = Sols que queda ocupado quien la hace (*todos* = toda la tripulación). Los efectos positivos solo se reciben si sale bien.

### Aleatorios

#### The Greenhouse Problem (`greenhouse-dilemma`)
Queda poca comida y los brotes aún son pequeños. Se repite cada 3 Sols.

| Opción | Quién | Efectos | Éxito | Ocupa |
|---|---|---|---|---|
| Eat the sprouts now | Todos | Salud +15, Oxígeno −10. Mañana: Oxígeno −10 | 100 % | — |
| Wait and share the food carefully | Biologist | Salud −10, Oxígeno +10. En 2 Sols: Salud +10 y **+1 cosecha** | 90 % | 2 |
| Use extra power for the plant lights | Engineer | Energía −15, Oxígeno +10, Salud +10, **+1 cosecha** | 85 % | 1 |

#### Space Tummy Ache (`space-bellies`)
La radiación espacial da dolor de barriga. Si se deja, empeora cada día. Se repite cada 5 Sols.

| Opción | Quién | Efectos | Éxito | Ocupa |
|---|---|---|---|---|
| Make shakes with good bacteria | Biologist | Salud +20, Energía −5, Oxígeno −5 | 95 % | 1 |
| Use the medicine box | Doctor | Salud +15, Fuerza de la base −5 | 90 % | — |
| Wait until later | Todos | Energía +5. Las tres mañanas siguientes: Salud −5, −5 y −10 | 100 % | — |

#### The Space Blues (`mental-fog`)
La tripulación está triste y discute. Sale desde el Sol 4, o antes si hay un dolor de barriga sin tratar. Se repite cada 5 Sols.

| Opción | Quién | Efectos | Éxito | Ocupa |
|---|---|---|---|---|
| Hold a video game and music party | Commander | Salud +20, Energía −10 | 95 % | 1 |
| Play memory games and breathe calmly | Doctor | Salud +15, Energía −5 | 90 % | 1 |
| Ignore it and keep working | Todos | Salud −10. Mañana: Fuerza de la base −5 | 100 % | — |

#### Rover in the Sand (`rover-stuck`)
El robot explorador está atrapado en una duna. Sale una sola vez; si la opción elegida falla, vuelve a salir para reintentarlo.

| Opción | Quién | Efectos | Éxito | Ocupa |
|---|---|---|---|---|
| Drive it out by remote control | Engineer | Energía −10, Oxígeno +15, **rover libre** | 75 % | 1 |
| Go outside in space suits to rescue it | Todos | Oxígeno −5, Salud −10, Energía +10, **rover libre**. 50 % de una roca especial: Energía +10. Si falla: Salud −5 más | 70 % | 1 (todos) |
| Leave the robot behind | Todos | Energía +5, Fuerza de la base −10 | 100 % | — |

#### Dust on the Solar Panels (`dust-panels`)
Una tormenta cubre los paneles de polvo. Se repite cada 6 Sols.

| Opción | Quién | Efectos | Éxito | Ocupa |
|---|---|---|---|---|
| Go outside and wipe the panels | Todos | Oxígeno −15, Salud −5, Energía +20 | 85 % | 1 (todos) |
| Program the panels to shake off the dust | Engineer | Energía −10, Fuerza de la base +5. Mañana: Energía +15 | 90 % | 1 |
| Wait for the storm to pass | Todos | Energía +5, Fuerza de la base −5. **Tormenta de polvo** 2 Sols: Energía −10 cada mañana | 100 % | — |

### Relleno

#### A Calm Sol (`quiet-sol`)
Día sin emergencias, para cuidar la base.

| Opción | Quién | Efectos | Éxito | Ocupa |
|---|---|---|---|---|
| Rest together | Todos | Salud +5, Energía −5 | 100 % | — |
| Check the base walls | Engineer | Fuerza de la base +5, Energía −5 | 95 % | 1 |
| Take care of the greenhouse | Biologist | Oxígeno +5, Energía −5 | 95 % | 1 |

### Objetivo: red de sensores sísmicos (misión InSight)

Cadena: fabricar → colocar → (posible avería) → terremoto con o sin aviso.

#### Build 3 Earthquake Sensors (`sensors-fabricate`)
Sale una sola vez mientras los sensores no estén fabricados; si la opción falla, vuelve a salir.

| Opción | Quién | Efectos | Éxito | Ocupa |
|---|---|---|---|---|
| Print them with the 3D printer | Engineer | Energía −25, **sensores fabricados** | 90 % | 1 |
| Take parts from the old rover | Todos | Fuerza de la base −10, Energía −5, **sensores fabricados** | 80 % | 1 (todos) |
| Build them with duct tape and patience | Todos | Energía −10, **sensores fabricados**. Provoca «The Dusty Sensor» en 1–2 Sols | 70 % | — |

#### Place the Sensors Outside (`sensors-place`)
Sale con los sensores fabricados y menos de 3 colocados, como mucho cada 2 Sols. Reintento si falla.

| Opción | Quién | Efectos | Éxito | Ocupa |
|---|---|---|---|---|
| One long walk outside | Todos | Energía −35, Oxígeno −25, **3 sensores colocados** | 75 % | 1 (todos) |
| Use the precision tool | Engineer | Energía −30, Oxígeno −15, **3 sensores colocados** | 90 % | 2 |
| Two walks on two different Sols | Todos | Energía −20, Oxígeno −15, 2 sensores. Mañana: Energía −10, Oxígeno −10, el tercero, y toda la tripulación ocupada 1 Sol | 85 % | — hoy |

#### The Dusty Sensor (`sensor-dust`)
Un sensor deja de enviar datos. Sale una sola vez, cuando hay algún sensor colocado; montarlos con cinta adhesiva lo programa para 1–2 Sols después.

| Opción | Quién | Efectos | Éxito | Ocupa |
|---|---|---|---|---|
| Go outside and fix it | Todos | Energía −10, Oxígeno −5. Si falla: −1 sensor | 85 % | 1 (todos) |
| Restart it from the base | Engineer | Energía −5. Si falla: −1 sensor | 80 % | 1 |
| Leave it | Todos | −1 sensor | 100 % | — |

#### Marsquake! (`quake-warned`) — importante, 20 s
Terremoto **con aviso**. Se programa 1–2 Sols después de completar la red, si se completó antes del Sol 13. Opción por defecto: *evacuate*.

| Opción | Quién | Efectos | Éxito | Ocupa |
|---|---|---|---|---|
| Make the base walls stronger | Engineer | Energía −10. Si falla: Fuerza de la base −10 | 95 % | 1 |
| Move everyone to the safe room | Todos | Oxígeno −5, Energía −5. Si falla: Salud −10 | 90 % | — |

#### Surprise Marsquake! (`quake-unwarned`) — importante, 20 s
Terremoto **sin aviso**. Sale desde el Sol 14 si la red no dio la alerta. Al aparecer ya quita **Fuerza de la base −20**.

| Opción | Quién | Efectos | Éxito | Ocupa |
|---|---|---|---|---|
| Fix the damage | Todos | Energía −10. Si falla: Fuerza de la base −10 | 85 % | 1 (todos) |

### Objetivo: generador de oxígeno MOXIE

Tres fases (33 %, 66 %, 100 %). Todas permiten reintento si fallan.

#### Build MOXIE: Part 1 (`moxie-phase-1`)

| Opción | Quién | Efectos | Éxito | Ocupa |
|---|---|---|---|---|
| Build it as fast as you can | Todos | Energía −25, **MOXIE 33 %** | 80 % | 1 (todos) |
| Build it slowly and carefully | Engineer | Energía −15, **MOXIE 33 %** | 95 % | 2 |
| Use parts from the greenhouse | Todos | Energía −10, Oxígeno −10, **MOXIE 33 %** | 85 % | — |

#### MOXIE vs. the Greenhouse (`moxie-phase-2`)

| Opción | Quién | Efectos | Éxito | Ocupa |
|---|---|---|---|---|
| Give MOXIE all the power | Todos | Energía −20, Salud −5, **MOXIE 66 %** | 85 % | — |
| Make a power schedule | Biologist | Energía −10, **MOXIE 66 %** | 95 % | 1 |
| Turn off the lab and greenhouse for one Sol | Commander | Energía −5, Salud −10, **MOXIE 66 %** | 90 % | 1 |

#### MOXIE: The Last Step (`moxie-phase-3`)

| Opción | Quién | Efectos | Éxito | Ocupa |
|---|---|---|---|---|
| Clean the filter by hand | Todos | Energía −10, Oxígeno −5, **MOXIE 100 %** | 80 % | 1 (todos) |
| Swap in a new filter | Engineer | Energía −15, **MOXIE 100 %** | 90 % | 1 |
| Ignore it | Todos | **MOXIE vuelve al 33 %** | 100 % | — |

### Automático

#### MOXIE Works! (`moxie-done`)
Sale en cuanto MOXIE llega al 100 %. Una sola opción, *We did it!*: Salud +5. Desde aquí no se pierde oxígeno cada Sol.

### Tiempo real

#### Solar Storm Alert! (`rt-solar-flare`) — importante
Sale si la API DONKI de la NASA registra una llamarada de clase M o X en los últimos 3 días, y enseña la clase y la fecha reales. Todas las opciones activan la **alerta solar** 2 Sols, que bloquea la ayuda de la Tierra. No se puede pedir ayuda sobre este evento.

| Opción | Quién | Efectos | Éxito | Ocupa |
|---|---|---|---|---|
| Give the crew a probiotic boost | Biologist | Oxígeno −5, Salud +5. Si falla: Salud −5 | 90 % | 1 |
| Turn on the base shields | Engineer | Energía −10. Si falla: Salud −5 y Fuerza de la base −5 | 90 % | 1 |
| Hide in the middle room | Todos | Salud −5, Energía −5 | 100 % | — |

Al ejecutar desde el editor de Godot hay un botón de depuración en la ventana de Marte que simula la llamarada sin depender de la API (en la web publicada no aparece).

---

## 7. Ayuda de la Tierra

Evento auxiliar basado en el retraso real de las comunicaciones con Marte.

- Se pide sobre el evento del día. El problema queda **en espera**, se pasa al Sol siguiente y vuelve cuando llega la respuesta, con una **pista** de Control de Misión (`earth_hint`).
- **Dos formas de pedirla:**

| Opción | Coste | La respuesta llega en |
|---|---|---|
| Full report (lo cuenta el Comandante) | Energía −5 | 1 Sol |
| Quick message | Nada | 2 Sols |

- **En pantalla:** el botón es la radio de la base (la Tierra con ondas si está lista, una batería si se recarga, las ondas tachadas si no hay señal). La ventana enseña Marte y la Tierra unidos por la señal, con la distancia y los minutos, y una tarjeta por opción. La pista vuelve en una caja «MESSAGE FROM EARTH».

- **Recarga:** la radio tarda **4 Sols** en poder usarse otra vez.
- **No se puede pedir:** durante la lectura, en los terremotos (hay cuenta atrás), en la alerta solar, en «MOXIE Works!», ni mientras dure una alerta solar.
- El juego muestra el dato fijo: Marte está a unos 225 millones de km y un mensaje de radio tarda unos 12 minutos.

## 8. Libro de palabras

Glosario de **18 términos** (`game/Data/glossary.json`). Cada uno tiene título, una definición sencilla y un dato de la NASA. Se desbloquean al salir el evento que los usa y se consultan con el botón WORD BOOK sin parar la partida.

| Tema | Términos |
|---|---|
| Marte y el tiempo | Sol, Regolith, Dust Storm, Marsquake, Light-minutes |
| Lugares | Jezero Crater, Gale Crater |
| Misiones y aparatos | Perseverance, Opportunity, InSight, SEIS Seismometer, MOXIE, Splitting CO₂ |
| Sol y radiación | Solar Flare, Coronal Mass Ejection (CME), Space Radiation |
| Salud | Probiotics, OSDR |

---

## 9. Fuentes de datos

### Datos en vivo (APIs de la NASA)

Las dos integraciones activas se ejecutan desde Godot (no desde el mando ni el backend) y usan un tiempo de espera de 3 s con alternativa local. La imagen se precarga al iniciar el juego; DONKI se consulta al comenzar la partida.

| Fuente | Dirección | Para qué se usa | Sin conexión |
|---|---|---|---|
| **DONKI** (clima espacial), llamaradas solares | `https://api.nasa.gov/DONKI/FLR?startDate=…&api_key=…` | `game/Scripts/turn_manager.gd`: al comenzar la partida consulta los últimos 3 días. Una llamarada M/X activa «Solar Storm Alert!» y muestra su clase y fecha reales. | No hay alerta (o se simula con el botón de depuración). |
| **NASA Image and Video Library** | `https://images-api.nasa.gov/search?q=jezero%20crater&media_type=image` | `game/Scripts/nasa_api.gd` la consulta al inicio; `game/Scripts/intro.gd` usa la imagen de Jezero como fondo y muestra su título como crédito. | Imagen local de ESA Mars Express. |

DONKI se consulta con la clave pública `DEMO_KEY`, que tiene un límite bajo de peticiones; para la demo conviene una clave gratuita de `api.nasa.gov`. La consulta de imágenes no usa esa clave.

### Datos de misiones reales en los eventos

Cada evento lleva un «NASA fact» y varios añaden términos al libro. Estos textos están escritos a mano en `events.json` y `glossary.json`.

| Misión o fuente | Dato que se usa | Dónde aparece |
|---|---|---|
| **InSight** y su sismómetro **SEIS** | Registró más de 1.300 terremotos marcianos, de hasta magnitud 5 aproximadamente; colocó el sensor en el suelo con un brazo robótico; el polvo fue un problema. | Cadena de sensores y terremotos |
| **MOXIE** (a bordo de Perseverance) | Fabricó oxígeno a partir del CO₂ del aire de Marte, unos 12 gramos por hora. | Cadena de MOXIE |
| **Perseverance** | Aterrizó en el cráter Jezero en febrero de 2021. | Intro, rover atrapado, libro |
| **Curiosity** | Encontró arcilla, que se forma con agua, en el cráter Gale; su instrumento RAD mide la radiación. | Invernadero, libro |
| **Spirit** | Quedó atrapado en arena blanda en 2009. | Rover atrapado |
| **Opportunity** | El viento limpiaba sus paneles; una tormenta de polvo acabó con la misión en 2018. | Polvo en los paneles |
| **OSDR** (repositorio abierto de ciencia espacial de la NASA) | Estudios con modelos de intestino y de cerebro: el probiótico *Lacticaseibacillus rhamnosus GG* ayuda frente a la radiación; el viaje espacial afecta al cerebro. | Dolor de barriga, tristeza espacial, invernadero |
| **DONKI** | Seguimiento de llamaradas solares y eyecciones de masa coronal. | Alerta solar, libro |
| Comunicaciones Tierra–Marte | Un mensaje tarda minutos en llegar, según la distancia. | Ayuda de la Tierra, libro |

### Ficheros de datos del juego

| Fichero | Contenido |
|---|---|
| `game/Data/events.json` | Los 16 eventos: textos, condiciones, opciones, efectos, probabilidades y ocupación. Fuente de verdad de las cifras. |
| `game/Data/glossary.json` | Los 18 términos del libro de palabras. |
| `docs/es/protocol.md` | Contrato de mensajes entre Godot, backend y mando. |

### Imágenes y sonido

| Recurso | Origen |
|---|---|
| Fondo de la intro (con conexión) | NASA Image and Video Library |
| Fondo de la intro (sin conexión) y del menú | Imagen de ESA Mars Express guardada en `game/Images/` |
| Paisaje de la ventana de Marte | Dibujado por código (`mars_landscape.gd`); la tormenta de arena es un shader de ruido |
| Marco de la cabina, logos de las barras, casco y botón EVENT | Pixel art propio del equipo en `game/Images/` |
| Música y efectos de sonido | Ficheros del equipo en `game/Sound/`. Al acabar la partida suena `Succes_SFX` si se gana y `Failure_SFX` si se pierde (además de los de cada decisión) |
| Sonidos en bucle | `Texting_SFX` mientras se escribe el texto de un evento y `Sandstorm_SFX` mientras la ventana de Marte enseña una tormenta de arena (clave `sandstorm` en `sfx.gd`, con fundido al apagarse) |
| Cursor del ratón | Cohete en pixel art (`Raton.png`, ajuste de proyecto `mouse_cursor/custom_image`). Solo sustituye a la flecha: las tarjetas de opciones usan la flecha para no cambiarlo por la manita del sistema |

### Fuentes previstas y todavía no conectadas

Estas APIs aparecen en el diseño, pero el juego todavía no las consulta:

| Fuente | Para qué se pensó | Qué se usa ahora |
|---|---|---|
| JPL Horizons | Distancia Tierra–Marte del día en la ayuda de la Tierra | Dato fijo: 225 millones de km y 12 minutos |
| Mars Rover Photos | Fotos reales de Perseverance | Paisaje dibujado por código |
| InSight Weather / MEDA | Racha de viento que da energía en «Polvo en los paneles» | Sin bonificación |
| DONKI, eyecciones de masa coronal (`/DONKI/CME`) | Segunda fuente para la alerta solar | Solo llamaradas (`/DONKI/FLR`) |
