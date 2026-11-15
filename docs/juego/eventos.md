# Catálogo de eventos

Todos los eventos de la partida. Las reglas generales (votación, roles, ayuda de la Tierra…) están en [diseno.md](diseno.md).

- **Las cifras son las de [`game/Data/events.json`](../../game/Data/events.json).** Si cambiáis un evento, cambiadlo allí y aquí.
- **Quién:** «Todos» es votación general; un rol significa que solo ese rol puede elegir la opción (y solo aparece si ese rol está en la partida).
- **Sol+N:** el efecto se aplica N Sols después.
- Cada evento lleva su `id` de `events.json` para encontrarlo rápido.

## Índice

| Tipo | Eventos |
|---|---|
| [Aleatorios](#eventos-aleatorios) | [Tormenta de radiación solar](#tormenta-de-radiación-solar) · [El dilema del invernadero](#el-dilema-del-invernadero) · [Barrigas espaciales](#barrigas-espaciales) · [Niebla mental y aislamiento](#niebla-mental-y-aislamiento) · [Rover atrapado en la arena](#rover-atrapado-en-la-arena) · [Polvo en los paneles](#polvo-en-los-paneles) |
| [Objetivo: sensores sísmicos](#objetivo-red-de-sensores-sísmicos-insight) | [S1 Fabricar](#s1-fabricar-los-3-sensores) → [S2 Colocar](#s2-salir-a-colocar-los-3-sensores) → [S3 Sensor tapado](#s3-sensor-tapado-por-polvo) → [S4 Terremoto](#s4-terremoto-marciano) |
| [Objetivo: MOXIE](#objetivo-generador-de-oxígeno-moxie) | [M1 Primera fase](#m1-primera-fase) → [M2 Contra el invernadero](#m2-moxie-contra-el-invernadero) → [M3 Fallo en el filtro](#m3-fallo-en-el-filtro) → [M4 MOXIE funciona](#m4-moxie-funciona) |
| [Especiales](#eventos-especiales) | [Pedir ayuda a la Tierra](#pedir-ayuda-a-la-tierra) · [Alerta solar en tiempo real](#alerta-solar-en-tiempo-real) |

---

## Eventos aleatorios

### Tormenta de radiación solar
`solar-storm` · **Fuente NASA:** DONKI, eyección de masa coronal (CME)

> Los sensores detectan una CME acercándose a Marte. Hay que proteger a la tripulación antes de que llegue la radiación.

| Opción | Quién | Efectos | Resultado |
|---|---|---|---|
| Activar escudos magnéticos (NFC `NFC_SHIELD`) | Todos | −20 Energía | Los escudos desviaron la radiación, pero consumieron mucha batería. |
| Redirigir energía de los laboratorios | Ingeniero | −5 Energía, −5 Integridad | El Ingeniero optimizó los escudos con poca batería, a costa de algo de desgaste. |
| Mantener los experimentos activos | Todos | +5 Energía, −20 Integridad, −10 Salud | Ahorrasteis energía, pero la radiación dañó los sistemas exteriores y a la tripulación. |

### El dilema del invernadero
`greenhouse-dilemma` · **Fuente NASA:** misión Curiosity, análisis del suelo del cráter Gale (minerales y arcillas)

> Las raciones se acaban y todos tienen hambre. La Bióloga cultiva patatas «marcianas» con probióticos en suelo del cráter Gale, pero los brotes aún son diminutos. ¿Comemos ya o esperamos?

| Opción | Quién | Efectos | Resultado |
|---|---|---|---|
| Comerse los brotes ya | Todos | +15 Salud, −10 Oxígeno · Sol+1: −10 Oxígeno | ¡Qué rico! Pero sin plantas, el aire de la base empieza a viciarse. |
| Esperar y racionar comida | Bióloga | −10 Salud, +10 Oxígeno · Sol+2: +10 Salud (cosecha) | La Bióloga protegió el cultivo. ¡Las plantas crecen fuertes y purifican el aire! |
| Usar luces de cultivo | Ingeniero | −15 Energía, +10 Oxígeno, +10 Salud | El Ingeniero aceleró la cosecha con luz artificial, aunque gastó mucha batería. |

### Barrigas espaciales
`space-bellies` · **Persistente** · **Fuente NASA:** OSDR, estudio sobre radiación y probióticos (*Lacticaseibacillus rhamnosus* GG), DOI 10.26030/y1ww-ep94

> La radiación está molestando a la tripulación. Si no se cura hoy, mañana será peor: cada Sol sin resolver cuesta salud.

| Opción | Quién | Efectos | Resultado |
|---|---|---|---|
| Batidos con probióticos | Bióloga | +20 Salud, −5 Energía, −5 Oxígeno (consume plantas) | ¡Ciencia al rescate! Los probióticos protegieron los intestinos del equipo frente a la radiación. |
| Botiquín estándar (NFC `NFC_MEDKIT`) | Médico | +15 Salud, −5 Integridad | El Médico alivió los síntomas rápidamente usando las reservas del botiquín. |
| Posponer | Todos | +5 Energía. Queda pendiente: −5, −5 y −10 Salud en los tres Sols siguientes; después se cierra. | Lo dejáis para más tarde: el equipo aguanta, pero mañana estará peor. |

**Dato real:** un estudio de la NASA vio que la bacteria *L. rhamnosus* GG puede modular la respuesta del intestino humano a la radiación espacial.

### Niebla mental y aislamiento
`mental-fog` · **Condición:** a partir del Sol 5, o antes si «Barrigas espaciales» está pendiente · **Fuente NASA:** OSDR, efectos del vuelo espacial en el cerebro humano (organoides cerebrales), DOI 10.26030/twtb-sc40

> Lleváis muchos Sols viendo solo rocas rojas. En la Tierra se ha estudiado que el aislamiento y el vuelo espacial afectan al cerebro. El equipo está triste, despistado y discute por todo.

| Opción | Quién | Efectos | Resultado |
|---|---|---|---|
| Torneo de videojuegos y música | Comandante (`generalist`) | +20 Salud, −10 Energía | La Comandante subió la moral del equipo. ¡Risas en Marte! |
| Ejercicios de memoria y relajación | Médico | +15 Salud, −5 Energía | El Médico ayudó a entrenar vuestros cerebros contra el estrés espacial. |
| Ignorarlo y trabajar en silencio | Todos | −10 Salud · Sol+1: −5 Integridad | Al estar distraídos, alguien pulsó un botón equivocado y dañó un panel. |

**Dato real:** los vuelos espaciales alteran programas moleculares del cerebro humano, según estudios con organoides cerebrales.

### Rover atrapado en la arena
`rover-stuck` · **Fuente NASA:** zona de aterrizaje de Curiosity, dunas de Rocknest · **API:** fotos recientes de Perseverance (Mars Rover Photos)

> Vuestro pequeño robot explorador se ha quedado atascado en una duna y ha perdido la señal. Tiene datos valiosos dentro.

| Opción | Quién | Efectos | Resultado |
|---|---|---|---|
| Control remoto desde la base | Ingeniero | −10 Energía, +15 Oxígeno (muestras de hielo) | El Ingeniero reprogramó las ruedas y lo liberó a distancia. Traía muestras de hielo que dan aire. |
| Salir con trajes a rescatarlo | Todos | −5 Oxígeno, −10 Salud, +10 Energía · 50 %: +10 Energía extra (roca especial) | ¡Paseo espacial épico! Rescatasteis el robot y recogisteis rocas a mano. |
| Abandonar el robot | Todos | +5 Energía, −10 Integridad (sin rover no hay quien inspeccione el exterior) | La base está a salvo, pero perdimos un valioso explorador. |

### Polvo en los paneles
`dust-panels` · **Fuente NASA:** misión Opportunity y tormentas de polvo marcianas · **API:** InSight Weather; si hay rachas fuertes de viento, +5 Energía gratis

> Una tormenta de polvo ha cubierto los paneles solares de la base. Producen cada vez menos electricidad y las baterías bajan. Si no hacéis algo, mañana habrá aún menos luz.

| Opción | Quién | Efectos | Resultado |
|---|---|---|---|
| Limpiar los paneles con trajes | Todos | −15 Oxígeno, −5 Salud, +20 Energía | Barristeis el polvo a mano. Costó aire, pero los paneles vuelven a brillar. |
| Reprogramar los paneles para que se sacudan | Ingeniero | −10 Energía · Sol+1: +15 Energía, +5 Integridad | El Ingeniero los hizo vibrar para soltar el polvo. Gasta batería hoy, pero ahorra trabajo mañana. |
| Racionar la electricidad | Todos | +10 Energía, −10 Salud, −5 Integridad (el frío daña las tuberías) | Sobrevivisteis con lo justo, pero hace frío en la base y las tuberías sufren. |

**Dato real:** Opportunity siguió funcionando años porque el viento limpió sus paneles. Vosotros no podéis esperar al viento.

---

## Objetivo: red de sensores sísmicos (InSight)

Hay que fabricar y colocar 3 sensores. **Si están colocados antes del Sol 20**, el terremoto avisa con un Sol de antelación (S4 con aviso); si no, llega sin avisar.

### S1. Fabricar los 3 sensores
`sensors-fabricate` · **Condición:** objetivo activo, hasta el Sol 17 · **Fuente NASA:** InSight, sismómetro SEIS (aterrizó en 2018 para escuchar los «terremotos marcianos»)

> Para vigilar el suelo de Marte necesitáis una red de tres sensores sísmicos. Son delicados: un solo golpe y dejan de funcionar. Hay que decidir cómo construirlos todos antes de salir.

| Opción | Quién | Efectos | Resultado |
|---|---|---|---|
| Imprimirlos con la impresora 3D | Ingeniero | −25 Energía · 3 sensores fabricados | El Ingeniero imprimió los tres sensores pieza a pieza. Funcionan perfecto. |
| Reciclar piezas del rover viejo | Todos | −10 Integridad, −5 Energía · 3 sensores fabricados | Desmontasteis el rover viejo. Sensores listos, aunque la base perdió piezas útiles. |
| Montarlos con cinta americana | Todos | −10 Energía · 3 sensores fabricados, pero **uno fallará**: provoca S3 en los 3 Sols siguientes | No es bonito, pero con suficiente cinta todo se sujeta… de momento. |

### S2. Salir a colocar los 3 sensores
`sensors-place` · **Condición:** S1 completado · **Fuente NASA:** InSight, despliegue del sismómetro con el brazo robótico

> Los tres sensores están listos. Hay que sacarlos a la superficie, repartirlos lejos de la base para detectar los temblores y dejarlos bien asentados. Ahí fuera el aire cuesta caro.

| Opción | Quién | Efectos | Resultado |
|---|---|---|---|
| Una sola salida larga | Todos | −35 Energía, −25 Oxígeno · 3 colocados | Un paseo espacial largo y agotador, pero los tres sensores ya escuchan el suelo. |
| Salida con herramienta de precisión | Ingeniero | −30 Energía, −15 Oxígeno · 3 colocados | El Ingeniero los asentó con precisión. Menos tiempo fuera, menos aire gastado. |
| Dos salidas en dos Sols | Todos | −20 Energía, −15 Oxígeno · 2 colocados · Sol+1: −10 Energía, −10 Oxígeno, el 3.º colocado | Salisteis en dos turnos para respirar entre medias. Más lento, pero más seguro. |

### S3. Sensor tapado por polvo
`sensor-failure` · **Condición:** lo provoca «cinta americana» en S1 · **Fuente NASA:** el polvo acumulado limitó la operación de InSight

> Uno de los sensores ya no manda datos. Una capa de polvo lo cubre o el cable se ha soltado. Si lo dejáis, ya no cuenta.

| Opción | Quién | Efectos | Resultado |
|---|---|---|---|
| Salir a repararlo | Todos | −10 Energía, −5 Oxígeno | Lo desenterrasteis y volvió a transmitir. |
| Reprogramarlo a distancia | Ingeniero | −5 Energía | El Ingeniero activó el limpiaparabrisas y recuperó la conexión. |
| Dejarlo y fabricar otro | Todos | −1 sensor colocado y fabricado; vuelve a abrirse S1 | Lo abandonasteis. |

### S4. ¡Terremoto marciano!
**Emergencia: 20 s para elegir** · **Fuente NASA:** InSight detectó más de 1.300 sismos, de hasta magnitud 5

**Con aviso** (`quake-warned`, red completa antes del Sol 20):

> ¡Alerta de la red sísmica! Se detecta un sismo a punto de llegar a la base. Tenéis un Sol para prepararos.

| Opción | Quién | Efectos | Resultado |
|---|---|---|---|
| Reforzar la estructura | Ingeniero | −10 Energía, Integridad intacta | Gracias al aviso, el Ingeniero reforzó los puntos débiles antes del temblor. |
| Evacuar a la zona segura | Todos | −5 Oxígeno, −5 Energía, Integridad intacta | Todos estaban a salvo cuando llegó el temblor. |

**Sin aviso** (`quake-unwarned`, a partir del Sol 8 si la red no estaba completa a tiempo):

> El suelo tiembla sin avisar. La base cruje y hay daños. Sin red de sensores no hubo tiempo de prepararse.

| Opción | Quién | Efectos |
|---|---|---|
| Reparar los daños | Todos | −20 Integridad, −10 Energía |

---

## Objetivo: generador de oxígeno MOXIE

MOXIE se monta en **3 fases** (33 + 33 + 34 %). Al llegar al 100 % desaparece el consumo pasivo de Oxígeno por Sol (−4 hoy; ver [diseno.md](diseno.md#equilibrio-de-la-dificultad)).

### M1. Primera fase
`moxie-phase-1` · **Condición:** objetivo activo · **Fuente NASA:** MOXIE, instrumento del rover Perseverance; en 2021 produjo oxígeno a partir del CO₂ marciano

> En Marte casi no hay oxígeno, pero el aire es casi todo CO₂. MOXIE separa el oxígeno del carbono. Empezar a montarlo exige mucha energía.

| Opción | Quién | Efectos | Resultado |
|---|---|---|---|
| Montaje a toda máquina | Todos | −25 Energía · MOXIE +33 % | Trabajasteis sin parar. La base se quedó casi a oscuras, pero el montaje avanza. |
| Montaje cuidadoso | Ingeniero | −15 Energía · MOXIE +33 % | El Ingeniero optimizó el consumo de cada herramienta. |
| Montar con piezas del invernadero | Todos | −10 Energía, −10 Oxígeno · MOXIE +33 % | Funciona, pero las plantas se resienten. |

### M2. MOXIE contra el invernadero
`moxie-phase-2` · **Condición:** M1 completado · **Fuente NASA:** repartir la energía entre instrumentos es un problema real de las misiones

> MOXIE necesita la misma energía que las luces del invernadero. La Bióloga teme que sus cultivos se estropeen si les quitáis corriente. Hay que repartir sin que ninguno se apague.

| Opción | Quién | Efectos | Resultado |
|---|---|---|---|
| Priorizar a MOXIE | Todos | −20 Energía, −5 Salud · MOXIE +33 % | MOXIE avanza, pero los cultivos de la Bióloga se resienten. |
| Horarios compartidos | Bióloga | −10 Energía · MOXIE +33 % | La Bióloga diseñó turnos: MOXIE de noche, plantas de día. Todos felices. |
| Apagar laboratorio e invernadero un Sol | Comandante (`generalist`) | −5 Energía, −10 Salud · MOXIE +33 % | Un sacrificio duro, pero nadie discute las órdenes del Comandante. |

### M3. Fallo en el filtro
`moxie-phase-3` · **Condición:** M2 completado · **Fuente NASA:** MOXIE usa un filtro de partículas para limpiar el aire antes de convertirlo · **API:** InSight Weather o datos de MEDA (Perseverance)

> El filtro de MOXIE se ha atascado con polvo marciano. Si no se limpia, la máquina se estropeará.

| Opción | Quién | Efectos | Resultado |
|---|---|---|---|
| Limpiarlo a mano | Todos | −10 Energía, −5 Oxígeno · MOXIE +34 % | Cuesta aire, pero funciona. |
| Cambiar el filtro | Ingeniero | −15 Energía · MOXIE +34 % | Filtro nuevo, ninguna sorpresa. |
| Ignorarlo | Todos | MOXIE −33 % (retrocede una fase) | Se atascó del todo. Habrá que rehacer el trabajo. |

### M4. MOXIE funciona
`moxie-done` · **Condición:** MOXIE al 100 % · **Fuente NASA:** MOXIE llegó a producir unos 12 g de oxígeno por hora, lo que respira un astronauta en unos minutos

> El generador está al 100 %. Un pitido confirma que el primer oxígeno sale de la atmósfera marciana. A partir de ahora, la base ya no pierde aire cada día.

Sin elección, solo celebración: **elimina el consumo pasivo de oxígeno**. *«¡MOXIE ha arrancado! El aire ya no es vuestro problema.»*

---

## Eventos especiales

Aún no están en `events.json` como eventos: las reglas de la ayuda están en el bloque `earth_help`.

### Pedir ayuda a la Tierra
**Fuente NASA:** retraso de las comunicaciones Tierra–Marte (4 a 24 minutos por mensaje) y operaciones del Control de Misión · **API:** JPL Horizons (distancia del día)

> Estáis ante un problema que no sabéis resolver. Podéis llamar al Control de Misión en la Tierra, pero Marte está muy lejos: el mensaje tarda en llegar, los ingenieros necesitan tiempo para estudiarlo y la respuesta tarda otro tanto en volver. Mientras esperáis, el problema sigue ahí.

| Opción | Quién | Efectos | Resultado |
|---|---|---|---|
| Enviar el informe completo | Comandante | −5 Energía (antena a máxima potencia). Respuesta rápida. | La Comandante transmitió todos los datos. Houston lo tiene claro y ya ha preparado una solución. |
| Enviar un mensaje rápido | Todos | Sin coste. Respuesta lenta. | El mensaje salió corto y sin detalles. Houston responderá lo que pueda. |
| Cancelar y decidir vosotros | Todos | Vuelve el evento normal; no se puede pedir ayuda sobre él ese Sol. | — |

Una vez por Sol. Qué devuelve exactamente la Tierra y cuánto tarda está en [decisiones pendientes](diseno.md#decisiones-pendientes).

### Alerta solar en tiempo real
**API:** DONKI (`/DONKI/FLR` o `/DONKI/CME`)

Si la API detecta una llamarada reciente de clase M o X, se interrumpe el turno:

> 📡 ¡Dato en vivo de la NASA! El [fecha real] el Sol lanzó una llamarada que acaba de alcanzar Marte.

Durante ese Sol y el siguiente no se puede pedir ayuda a la Tierra y hay que proteger a la tripulación:

| Opción | Quién | Efectos |
|---|---|---|
| Batidos con probióticos | Bióloga | −5 Oxígeno, +5 Salud |
| Escudos | Ingeniero | −10 Energía |

Ojo: las dos opciones son de rol. Hace falta una opción de votación general para cuando no estén ni la Bióloga ni el Ingeniero (ver [roles](diseno.md#roles)).
