# Sistema de Disponibilidad de la Tripulación y Tiempos por Tarea

Este documento define cómo gestionar el tiempo que tarda cada personaje (Ingeniero, Bióloga, Médico y Generalista) en realizar sus acciones dentro de una partida de **20 Sols**, así como el comportamiento del juego cuando todos los miembros están fuera de la base.

---

## 1. Regla Principal: Ocupación y Base Vacía

* **Bloqueo por tarea:** Cuando un jugador elige una opción asignada a su rol (o una salida conjunta), ese personaje queda marcado como **Ocupado / Fuera de la base** durante un número determinado de Sols (`0`, `1` o `2`).
* **Imposibilidad de selección:** Mientras un personaje esté fuera (tiene entrada en `GameState.crew_away`, que guarda el Sol en que vuelve), no puede ser seleccionado para resolver opciones exclusivas de su rol en turnos posteriores.
* **Regla de Base Vacía:** Al inicio de un nuevo Sol, el sistema comprueba quién está en la base. Si **los 4 personajes están ocupados (`GameState.base_is_empty()`)**, no hay nadie en la base para recibir o gestionar problemas: **no se genera ningún evento ese día** y se aplica el consumo diario normal. El turno no avanza solo: la pantalla muestra «The base is empty!» en fase de resolución, con el Sol en que vuelve la tripulación, y se espera a pulsar *Continue* (`TurnManager._empty_base_day()`).

---

## 2. Tiempos por Rol y Tipo de Tarea

Dado que la partida dura **20 Sols**, las duraciones están equilibradas entre `0` y `2` Sols para mantener el ritmo sin bloquear la partida en exceso:

| Rol | Tarea Instantánea (`0 Sols`) | Tarea Estándar (`1 Sol`) | Expedición / Tarea Larga (`2 Sols`) |
| :--- | :--- | :--- | :--- |
| **Generalista** (`generalist`) | Comunicaciones rápidas y envío de informes a la Tierra. | Gestión de moral, protocolos de emergencia y organización de turnos. | *No tiene tareas de 2 Sols (siempre supervisa el mando).* |
| **Médico** | Aplicar botiquín de primeros auxilios o tratamientos rápidos. | Terapias cognitivas, relajación y seguimiento médico profundo. | *No tiene tareas de 2 Sols (permanece en enfermería).* |
| **Bióloga** | *Sus procesos biológicos requieren al menos 1 Sol.* | Preparación de batidos probióticos, racionamiento y reparto horario de luz. | Cultivo intensivo de cosechas y ciclos completos de laboratorio. |
| **Ingeniero** | *Sus reparaciones requieren al menos 1 Sol.* | Operaciones remotas desde consola (telemetría, luces, vibración de paneles, impresión 3D). | Salidas extravehiculares (EVA) largas: colocar sensores sísmicos o ensamblar fases pesadas de MOXIE. |
| **Votación General** | Decisiones pasivas, posponer problemas o racionar recursos dentro de la base. | **Salidas EVA grupales:** Todos salen con trajes a la vez (rescatar rover a pie, limpiar paneles o colocar sensores en grupo). **Deja la base vacía al Sol siguiente.** | *No aplica.* |

---

## 3. Desglose de Tiempos por Evento

### Eventos Generales
* **E1 (Invernadero):**
  * Opción 1 (General - Comer brotes): `0 Sols`
  * Opción 2 (Bióloga - Proteger cultivo): `2 Sols` ocupada
  * Opción 3 (Ingeniero - Luces artificiales): `1 Sol` ocupado
* **E2 (Barrigas Espaciales):**
  * Opción 1 (Bióloga - Batidos probióticos): `1 Sol` ocupada
  * Opción 2 (Médico - Botiquín estándar): `0 Sols`
  * Opción 3 (General - Posponer): `0 Sols`
* **E3 (Niebla Mental; en el juego, «The Space Blues»):**
  * Opción 1 (Generalista - Torneo videojuegos): `1 Sol` ocupado
  * Opción 2 (Médico - Ejercicios de memoria): `1 Sol` ocupado
  * Opción 3 (General - Ignorarlo): `0 Sols`
* **E4 (Rover Atrapado):**
  * Opción 1 (Ingeniero - Control remoto): `1 Sol` ocupado
  * Opción 2 (General EVA - Rescate con trajes): `1 Sol` **todos ocupados** (Base vacía mañana)
  * Opción 3 (General - Abandonar rover): `0 Sols`
* **E5 (Tormenta de Polvo):**
  * Opción 1 (General EVA - Limpiar con trajes): `1 Sol` **todos ocupados** (Base vacía mañana)
  * Opción 2 (Ingeniero - Vibrar paneles): `1 Sol` ocupado
  * Opción 3 (General - Racionar luz): `0 Sols`

### Objetivo 1: Sensores Sísmicos (InSight)
* **S1 (Fabricar sensores):**
  * Opción 1 (Ingeniero - Impresora 3D): `1 Sol` ocupado
  * Opción 2 (General - Reciclar rover viejo): `1 Sol` **todos ocupados**
  * Opción 3 (General - Cinta americana): `0 Sols`
* **S2 (Colocar los 3 sensores):**
  * Opción 1 (General EVA - Salida larga grupal): `1 Sol` **todos ocupados** (Base vacía mañana)
  * Opción 2 (Ingeniero EVA - Salida de precisión): `2 Sols` fuera de la base
  * Opción 3 (General - Dos salidas): `0 Sols` hoy, pero ocupa `1 Sol` a todos mañana
* **S3 (Sensor tapado):**
  * Opción 1 (General EVA - Salir a reparar): `1 Sol` **todos ocupados**
  * Opción 2 (Ingeniero - Limpieza remota): `1 Sol` ocupado
  * Opción 3 (General - Dejarlo): `0 Sols`
* **S4 (Terremoto Marciano):**
  * Opción 1 (Ingeniero - Reforzar estructura): `1 Sol` ocupado
  * Opción 2 (General - Evacuar zona segura): `0 Sols`
  * Opción sin aviso (General - Reparar daños): `1 Sol` **todos ocupados**

### Objetivo 2: Generador MOXIE
* **M1 (Primera fase MOXIE):**
  * Opción 1 (General - Montaje a toda máquina): `1 Sol` **todos ocupados**
  * Opción 2 (Ingeniero - Montaje cuidadoso): `2 Sols` ocupado
  * Opción 3 (General - Piezas del invernadero): `0 Sols`
* **M2 (MOXIE vs Invernadero):**
  * Opción 1 (General - Priorizar MOXIE): `0 Sols`
  * Opción 2 (Bióloga - Horarios compartidos): `1 Sol` ocupada
  * Opción 3 (Generalista - Apagar laboratorio): `1 Sol` ocupado
* **M3 (Fallo en el filtro):**
  * Opción 1 (General EVA - Limpiar a mano): `1 Sol` **todos ocupados**
  * Opción 2 (Ingeniero - Cambiar filtro): `1 Sol` ocupado
  * Opción 3 (General - Ignorar): `0 Sols`

### Especiales
* **Pedir ayuda a la Tierra:** `0 Sols` (con cualquiera de las dos opciones: informe completo o mensaje rápido).
* **Alerta Solar (DONKI):** `1 Sol` ocupado para el rol elegido (Bióloga o Ingeniero).

---

## 4. Implementación

Está en `GameState` (`game/Scripts/game_state.gd`); los Sols de cada opción salen de `away_sols` / `away_all` en `events.json`.

| Función | Qué hace |
|---|---|
| `send_away(role, sols)` / `send_all_away(sols)` | Deja ocupado a un tripulante o a toda la tripulación |
| `process_crew_return()` | Al amanecer, descuenta un Sol y devuelve quién vuelve a la base |
| `is_away(role)`, `away_sols_left(role)`, `available_crew()` | Consultas para bloquear opciones y saber quién vota |
| `base_is_empty()` | Si es `true`, ese Sol no sale evento |
