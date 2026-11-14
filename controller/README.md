# Frontend móvil NASA

Aplicación Vue para los cuatro móviles de la misión. Cada móvil entra con un
rol, recibe las opciones de la pregunta activa y envía la respuesta junto con
el rol seleccionado.

## Puesta en marcha

```bash
npm install
npm run dev
```

La aplicación espera que el backend esté disponible en:

```text
http://localhost:29222
```

Para abrir una sala, el identificador se pasa como query parameter:

```text
http://localhost:5173/?room=ID_DE_SALA
```

Ejemplo:

```text
http://localhost:5173/?room=sala-123
```

Si no se proporciona `room`, la aplicación no muestra los roles y solicita un
identificador de sala.

## Contrato HTTP del backend

La base de todas las rutas es:

```text
http://localhost:29222/api
```

El frontend centraliza estas llamadas en [`src/api.js`](./src/api.js).

### 1. Comprobar sala y roles disponibles

```http
GET /api/rooms/:roomId
```

El `roomId` debe estar codificado como parte de la URL.

Respuesta esperada:

```json
{
  "exists": true,
  "availableRoles": [
    "ingeniero",
    "biologo",
    "medico",
    "polivalente"
  ]
}
```

También se acepta el nombre `rolesAvailable` en lugar de
`availableRoles`, aunque se recomienda utilizar `availableRoles`.

Si la sala no existe:

```json
{
  "exists": false,
  "availableRoles": []
}
```

El frontend considera que una sala no es válida si `exists` es `false`.

### 2. Obtener las opciones de la pregunta

```http
GET /api/rooms/:roomId/question
```

Formato recomendado:

```json
{
  "options": [
    {
      "id": 1,
      "label": "Respuesta A",
      "value": 1
    },
    {
      "id": 2,
      "label": "Respuesta B",
      "value": 2
    }
  ]
}
```

Para simplificar, también se aceptan opciones como texto:

```json
{
  "options": [
    "Respuesta A",
    "Respuesta B",
    "Respuesta C",
    "Respuesta D"
  ]
}
```

El frontend busca las opciones en `response.options` o
`response.question.options`.

Para cada opción, el texto mostrado se obtiene en este orden:

1. `option.label`
2. `option.text`
3. La propia opción si es un string

El valor enviado al responder se obtiene en este orden:

1. `option.value`
2. `option.id`
3. La propia opción si es un valor simple

### 3. Reservar un rol

Se llama al entrar en la pantalla de un rol:

```http
POST /api/rooms/:roomId/roles/:role
```

No necesita body.

Los valores válidos de `role` son:

```text
ingeniero
biologo
medico
polivalente
```

El backend debe reservar el rol de forma atómica. Si otro móvil lo ha ocupado
entre la comprobación inicial y esta petición, debe responder con un error
`409 Conflict`.

Respuesta recomendada:

```json
{
  "role": "ingeniero",
  "available": false
}
```

### 4. Enviar una respuesta

```http
POST /api/rooms/:roomId/answers
Content-Type: application/json
```

Body:

```json
{
  "role": "ingeniero",
  "answer": 2
}
```

`role` es obligatorio y debe coincidir con uno de los roles válidos. `answer`
puede ser un número, string u objeto, pero debe conservarse sin perder
información para que el backend pueda reenviarlo a Godot.

Respuesta recomendada:

```json
{
  "accepted": true,
  "role": "ingeniero",
  "answer": 2
}
```

Después de recibir una respuesta correctamente, el móvil muestra una pantalla
de espera. El frontend actual no hace polling ni abre un canal en tiempo real
para la siguiente pregunta; esa parte deberá añadirse cuando se defina el
protocolo de comunicación con Godot.

## Errores

En respuestas HTTP no exitosas, el frontend intenta mostrar el campo `error`:

```json
{
  "error": "La sala no existe."
}
```

Se recomienda utilizar:

| Código | Uso |
| --- | --- |
| `400` | Body o parámetros inválidos |
| `404` | Sala o pregunta inexistente |
| `409` | Rol ocupado o conflicto de estado |
| `422` | Datos con formato válido pero contenido no aceptable |
| `500` | Error interno del servidor |

## CORS y red local

El backend debe permitir peticiones desde el origen donde se sirva Vue. Para
desarrollo puede permitir `*`, pero en producción conviene restringirlo.

Si los móviles físicos acceden desde la misma red Wi-Fi, `localhost` no apunta
al ordenador: apunta al propio móvil. En ese caso hay que:

1. Arrancar el backend escuchando en `0.0.0.0`.
2. Sustituir `localhost` en `src/api.js` por la IP local del ordenador.
3. Permitir el puerto `29222` en el firewall.

Ejemplo de URL para móviles físicos:

```text
http://192.168.1.25:29222/api
```

## Flujo completo

1. El móvil abre `/?room=ID_DE_SALA`.
2. El frontend llama a `GET /rooms/:roomId`.
3. Los roles ocupados aparecen deshabilitados.
4. El usuario selecciona un rol disponible.
5. El frontend llama a `POST /rooms/:roomId/roles/:role`.
6. El frontend navega a `/:role?room=ID_DE_SALA`.
7. El frontend llama a `GET /rooms/:roomId/question`.
8. El usuario selecciona una opción.
9. El frontend llama a `POST /rooms/:roomId/answers` con `role` y `answer`.
10. El móvil queda esperando la siguiente pregunta.

## Consideraciones para Godot

El backend debe separar el estado por sala. Como mínimo, cada sala necesita:

- Pregunta activa.
- Opciones de la pregunta.
- Roles ocupados y disponibles.
- Respuestas recibidas, asociadas a cada rol.

Godot no debe depender de los nombres visuales de los roles; debe utilizar
siempre los identificadores técnicos:

```text
ingeniero
biologo
medico
polivalente
```

El formato definitivo de comunicación entre backend y Godot todavía está
pendiente. Cuando se defina, debe mantener este contrato hacia los móviles o
adaptarse únicamente dentro del backend, sin hacer que Vue conozca el formato
interno de Godot.
