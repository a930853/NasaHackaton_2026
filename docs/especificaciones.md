# Contexto y Objetivo del Proyecto

Actúa como un Arquitecto de Software y Desarrollador Senior especializado en **Godot Engine (GDScript)**.
Necesito que diseñes e implementes la arquitectura base y un prototipo funcional sencillo (MVP) para un juego educativo y cooperativo de supervivencia en Marte llamado **"Supervivencia en Marte: 20 Sols"**.

El juego está diseñado para partidas de **unos 30 minutos (20 Sols en total)**, proyectado en una pantalla principal (Godot) donde 4 jugadores (Ingeniero, Bióloga, Médico y Comandante) debaten y toman decisiones conjuntas o específicas de rol (simuladas por ahora con botones en pantalla, preparadas para recibir señales de móviles/NFC en el futuro).

# 1. Arquitectura Recomendada (Cómo implementar los eventos y sistemas)

Para evitar código espagueti, implementa una **Arquitectura Guiada por Datos (Data-Driven)** combinada con una **Máquina de Estados Finitos (FSM)**:

1. **Base de Datos de Eventos (`events.json` o Diccionario en GDScript):** Cada evento es un objeto con `id`, `tipo`, `condiciones`, `duracion_sols` (por defecto 1, o varios si es un evento persistente), `terminos_cientificos` (IDs que se desbloquean al aparecer el evento), `opciones` (con restricción de rol opcional) y `efectos` (inmediatos o diferidos).

2. **Gestor de Condiciones Activas (`ActiveConditions`):** Para eventos que duran más de 1 Sol (ej. tormentas solares o de arena que duran 2-3 Sols aplicando penalizaciones o bloqueos cada mañana).

3. **Cola de Efectos Diferidos (`DelayedEffectsQueue`):** Para consecuencias futuras de decisiones (ej. cosechas listas en 2 Sols o respuestas de la Tierra).

4. **Libro de Tecnicismos (`GlossaryManager`):** Diccionario científico educativo. Cada vez que aparece un evento o dato de la NASA que contiene un término técnico (ej. *Sol, MOXIE, Cráter Jezero, Regolito, Eyección de Masa Coronal, Probióticos*), se añade automáticamente a la lista de términos desbloqueados para que los jugadores puedan consultarlo en cualquier momento desde un botón en la UI sin pausar ni romper el flujo.

5. **Gestor de Estado Global (`GameState` / Autoload):** Centraliza las variables críticas, el progreso de objetivos, los eventos activos/pendientes y las llamadas asíncronas a las APIs de la NASA (con valores por defecto/fallback si no hay internet).

# 2. Modelo de Datos del Juego (`GameState`)

### Variables Críticas (0 a 100)

* `salud`: int = 80 *(Condición de derrota si llega a 0. Objetivo secundario: mantener > 50% siempre).*

* `oxigeno`: int = 80 *(Condición de derrota si llega a 0. Consumo pasivo: `-5` por Sol hasta completar MOXIE).*

* `energia`: int = 80 *(Condición de derrota si llega a 0).*

* `integridad`: int = 80 *(Condición de derrota si llega a 0).*

### Progreso de la Partida y Objetivos (Reequilibrados a 20 Sols)

* `sol_actual`: int = 1 *(Meta: sobrevivir hasta el **Sol 20**).*

* `cosechas_completadas`: int = 0 *(Meta: 3).*

* `sensores_fabricados`: bool = false

* `sensores_colocados`: int = 0 *(Meta: 3. Si se logra **antes del Sol 13**, activa `alerta_sismica_activa = true`).*

* `moxie_progreso`: int = 0 *(0, 33, 66, 100% —3 fases para ajustarse a 20 Sols—. Al llegar a 100%, el consumo pasivo de oxígeno pasa a 0).*

* `rover_rescatado`: bool = false

* `active_conditions`: Array[Dictionary] *(Ej. `{"id": "tormenta_solar", "sols_restantes": 2, "efecto_diario": ...}`)*.

* `ayuda_tierra_usada_este_sol`: bool = false

* `terminos_desbloqueados`: Array[String] *(IDs de términos añadidos al Libro de Tecnicismos).*

### Roles Disponibles

* `GENERAL` (Votación de todos), `INGENIERO`, `BIOLOGA`, `MEDICO`, `COMANDANTE`.

# 3. Máquina de Estados del Turno (Bucle de 1 Sol)

El tiempo **avanza estrictamente por turnos** (1 evento principal por Sol, sin reloj continuo para permitir el debate educativo), reservando cuentas atrás de 20 segundos únicamente para emergencias críticas.

1. **`FASE_INICIO_SOL`:**

   * Incrementar `sol_actual`.

   * Aplicar consumo pasivo: `oxigeno -= 5` (si `moxie_progreso < 100`).

   * Procesar `active_conditions` (eventos multi-Sol activos: aplicar efectos diarios y restar 1 a `sols_restantes`).

   * Procesar `DelayedEffectsQueue` correspondientes al `sol_actual` (ej. cosechas listas, respuestas de la Tierra).

   * Consultar en segundo plano API de clima espacial (DONKI); si hay llamarada clase M/X, disparar **Evento en Tiempo Real** antes del evento normal.

2. **`FASE_SELECCION_EVENTO`:**

   * Elegir 1 evento válido del pool según condiciones (cadenas de objetivos o eventos aleatorios disponibles).

   * Desbloquear automáticamente en `GlossaryManager` los términos científicos asociados a ese evento (mostrando un pequeño aviso visual: *"Nuevo término añadido al Libro de Tecnicismos"*).

3. **`FASE_DECISION`:**

   * Mostrar título, descripción, dato NASA y las 3 opciones.

   * Permitir abrir el **Libro de Tecnicismos** en cualquier momento (modal superpuesto).

   * Permitir botón auxiliar **"Pedir ayuda a la Tierra"** (si no hay tormenta solar bloqueando comunicaciones y no se ha usado hoy).

   * Si el evento es crítico (ej. Terremoto S4), iniciar cuenta atrás de 20s.

4. **`FASE_RESOLUCION`:**

   * Aplicar efectos inmediatos de la opción elegida.

   * Encolar efectos futuros en `DelayedEffectsQueue` o activar condiciones multi-Sol en `active_conditions` si corresponde.

   * Mostrar texto de feedback narrativo.

5. **`FASE_FIN_SOL`:**

   * Comprobar **Derrota** (cualquier variable crítica $\le 0$).

   * Comprobar **Victoria** (`sol_actual == 20` y variables $> 0$). Calcular puntuación final según objetivos cumplidos.

   * Si continúa, volver a `FASE_INICIO_SOL`.

# 4. Catálogo de Eventos a Implementar

### A. Eventos Generales y Narrativos

* **E1 - El Dilema del Invernadero** *(Términos: `probioticos`, `crater_gale`)*:

  * *Opción 1 (GENERAL):* `+15 Salud`, `-10 Oxígeno`, y encolar `-10 Oxígeno` para `Sol + 1`.

  * *Opción 2 (BIOLOGA):* `-10 Salud`, `+10 Oxígeno`, y encolar `+10 Salud` + `+1 cosecha` para `Sol + 2`.

  * *Opción 3 (INGENIERO):* `-15 Energía`, `+10 Oxígeno`, `+10 Salud`, `+1 cosecha`.

* **E2 - Barrigas Espaciales (Radiación)** *(Términos: `radiacion_cosmica`, `osdr`)*:

  * *Opción 1 (BIOLOGA):* `+20 Salud`, `-5 Energía`, `-5 Oxígeno`.

  * *Opción 2 (MEDICO):* `+15 Salud`, `-5 Integridad`.

  * *Opción 3 (GENERAL - Posponer):* `+5 Energía`, activa condición persistente de 3 Sols (`-5 Salud`, `-5 Salud`, `-10 Salud`) y marca `E2_pendiente = true`.

* **E3 - Niebla Mental y Aislamiento** *(Condición: `sol_actual >= 4` O `E2_pendiente == true`)*:

  * *Opción 1 (COMANDANTE):* `+20 Salud`, `-10 Energía`.

  * *Opción 2 (MEDICO):* `+15 Salud`, `-5 Energía`.

  * *Opción 3 (GENERAL):* `-10 Salud`, y encolar `-5 Integridad` para `Sol + 1`.

* **E4 - Rover Atrapado en la Arena** *(Términos: `crater_jezero`, `perseverance`)*:

  * *Opción 1 (INGENIERO):* `-10 Energía`, `+15 Oxígeno`, `rover_rescatado = true`.

  * *Opción 2 (GENERAL):* `-15 Oxígeno`, `-10 Salud`, `+10 Energía`, `+10 Oxígeno`, `rover_rescatado = true` + 50% prob. de `+10 Energía` extra.

  * *Opción 3 (GENERAL):* `+5 Energía`, `-10 Integridad` (pierden el rover).

* **E5 - Tormenta de Polvo en los Paneles (Evento Multi-Sol)** *(Términos: `tormenta_polvo`, `opportunity`. Bonus API Clima: si viento fuerte -> `+5 Energía` gratis)*:

  * *Mecánica Multi-Sol:* Si no se limpian o reprograman hoy, activa una condición persistente durante **2 Sols** que resta `-10 Energía` cada amanecer hasta que pase la tormenta.

  * *Opción 1 (GENERAL):* `-15 Oxígeno`, `-5 Salud`, `+20 Energía` (resuelve la tormenta hoy).

  * *Opción 2 (INGENIERO):* `-10 Energía`, `+5 Integridad`, y encola `+15 Energía` para `Sol + 1` (resuelve la tormenta hoy).

  * *Opción 3 (GENERAL - Esperar):* `+5 Energía` hoy, pero activa la condición persistente de 2 Sols (`-10 Energía/Sol` y `-5 Integridad`).

### B. Cadena Objetivo 1: Red de Sensores Sísmicos (InSight)

* **S1 - Fabricar los 3 sensores** *(Términos: `sismometro_seis`, `insight`)*:

  * *Opción 1 (INGENIERO):* `-25 Energía`, `sensores_fabricados = true`.

  * *Opción 2 (GENERAL):* `-10 Integridad`, `-5 Energía`, `sensores_fabricados = true`.

  * *Opción 3 (GENERAL):* `-10 Energía`, `sensores_fabricados = true`, y programa evento **S3** dentro de 1 a 2 Sols.

* **S2 - Salir a colocar los 3 sensores** *(Condición: `sensores_fabricados == true`)*:

  * *Opción 1 (GENERAL):* `-35 Energía`, `-25 Oxígeno`, `sensores_colocados = 3`.

  * *Opción 2 (INGENIERO):* `-30 Energía`, `-15 Oxígeno`, `sensores_colocados = 3`.

  * *Opción 3 (GENERAL):* Hoy `-20 Energía`, `-15 Oxígeno` (`sensores_colocados = 2`). Encola para `Sol + 1`: `-10 Energía`, `-10 Oxígeno`, `sensores_colocados = 3`.

* **S3 - Sensor tapado por polvo** *(Condición: `sensores_colocados > 0`)*:

  * *Opción 1 (GENERAL):* `-10 Energía`, `-5 Oxígeno` (mantiene sensores).

  * *Opción 2 (INGENIERO):* `-5 Energía` (mantiene sensores).

  * *Opción 3 (GENERAL):* `sensores_colocados -= 1`.

* **S4 - ¡Terremoto Marciano!** *(Evento de clímax de objetivo, temporizador 20s. Término: `martemoto`)*:

  * *Si `sensores_colocados == 3` antes del Sol 13 (Con aviso):*

    * *Opción 1 (INGENIERO):* `-10 Energía` (0 daño).

    * *Opción 2 (GENERAL):* `-5 Oxígeno`, `-5 Energía` (0 daño).

  * *Si NO tiene los 3 sensores a tiempo (Sin aviso):*

    * Efecto automático: `-20 Integridad` + Única opción *(GENERAL)*: `-10 Energía`.

### C. Cadena Objetivo 2: Generador MOXIE (3 Fases de 33% para 20 Sols)

* **M1 - Primera fase de MOXIE** *(Condición: `moxie_progreso == 0`. Términos: `moxie`, `electrolisis_co2`)*:

  * *Opción 1 (GENERAL):* `-25 Energía`, `moxie_progreso = 33`.

  * *Opción 2 (INGENIERO):* `-15 Energía`, `moxie_progreso = 33`.

  * *Opción 3 (GENERAL):* `-10 Energía`, `-10 Oxígeno`, `moxie_progreso = 33`.

* **M2 - MOXIE contra el invernadero** *(Condición: `moxie_progreso == 33`)*:

  * *Opción 1 (GENERAL):* `-20 Energía`, `-5 Salud`, `moxie_progreso = 66`.

  * *Opción 2 (BIOLOGA):* `-10 Energía`, `moxie_progreso = 66`.

  * *Opción 3 (COMANDANTE):* `-5 Energía`, `-10 Salud`, `moxie_progreso = 66`.

* **M3 - Fallo en el filtro y montaje final** *(Condición: `moxie_progreso == 66`)*:

  * *Opción 1 (GENERAL):* `-10 Energía`, `-5 Oxígeno`, `moxie_progreso = 100`.

  * *Opción 2 (INGENIERO):* `-15 Energía`, `moxie_progreso = 100`.

  * *Opción 3 (GENERAL):* `moxie_progreso = 33` (retrocede una fase).

* **M4 - MOXIE funciona** *(Trigger automático al llegar a `moxie_progreso == 100`)*:

  * Mensaje de celebración y desactiva el consumo pasivo de `-5 Oxígeno/Sol`.

### D. Mecánicas Especiales y APIs NASA

1. **Evento Auxiliar: Pedir ayuda a la Tierra** *(Término: `minutos_luz`)*:

   * Disponible 1 vez por Sol sobre cualquier evento activo (si no hay tormenta solar activa).

   * Consulta distancia Tierra-Marte (`ssd.jpl.nasa.gov/api/horizons.api`, fallback: 225M km / 12 min).

   * Pone el evento actual en pausa (`Esperando respuesta`) y pasa al siguiente Sol.

   * *Opción 1 (COMANDANTE):* `-5 Energía`. En `Sol + 1` llega una pista educativa prioritaria.

   * *Opción 2 (GENERAL):* Sin coste. En `Sol + 2` llega la pista.

2. **Evento en Tiempo Real: Alerta Solar Multi-Sol (API DONKI)** *(Términos: `fulguracion_solar`, `cme`)*:

   * Consulta `api.nasa.gov/DONKI/FLR`. Si detecta llamarada M o X reciente (o simulada con un botón de debug), interrumpe el turno:

   * Activa una **condición persistente de 2 Sols** que bloquea "Pedir ayuda a la Tierra" por interferencias magnéticas y exige elegir entre proteger con probióticos (`BIOLOGA`: `-5 Oxígeno`, `+5 Salud`) o escudos (`INGENIERO`: `-10 Energía`).

# 5. Entregables que necesito de ti (Paso a Paso)

Por favor, mantén el código **sencillo, modular y bien comentado** en GDScript (Godot 4.x). Entrégame lo siguiente:

1. **Estructura de carpetas recomendada** para el proyecto en Godot.

2. **Código de `GameState.gd` (Singleton/Autoload):** Con todas las variables (configuradas a **20 Sols**), `active_conditions` (eventos multi-Sol), `DelayedEffectsQueue` y modificación segura de recursos.

3. **Código de `GlossaryManager.gd` (Libro de Tecnicismos):** Base de datos de términos científicos (al menos 10 términos iniciales con título, definición sencilla para niños/estudiantes y dato NASA) y funciones para desbloquear términos automáticamente al ocurrir los eventos.

4. **Código de `EventManager.gd`:** Estructura de datos de los eventos vinculada a los términos científicos y lógica para filtrar qué eventos pueden salir cada Sol.

5. **Código de `TurnManager.gd` y `MainUI.gd`:** Implementando la Máquina de Estados del Sol, una barra superior que muestre los **eventos multi-Sol activos** (ej. *"Tormenta Solar: 2 Sols restantes"*), un botón permanente para abrir el **Libro de Tecnicismos** y un botón de debug para *"Simular Llamarada Solar API"*.