// Textos de interfaz para los códigos del contrato (docs/protocol.md).

const ERRORS = {
  offline: 'No hay conexión con el centro de control. Inténtalo de nuevo en unos segundos.',
  invalid_code: 'Introduce un código de sala válido.',
  invalid_name: 'Escribe tu nombre (máximo 24 caracteres).',
  room_not_found: 'Esa sala no existe o ya se ha cerrado. Revisa el código de la pantalla.',
  room_full: 'La sala ya tiene cuatro tripulantes.',
  game_already_started: 'La misión ya ha empezado en esa sala.',
  invalid_token: 'Tu sesión anterior ha caducado. Vuelve a entrar.',
  role_taken: 'Ese rol ya está ocupado. Elige otro.',
  not_in_lobby: 'La misión ya ha empezado: no se puede cambiar de rol.',
  not_playing: 'La misión todavía no ha empezado.',
}

const REJECTIONS = {
  event_closed: 'Esta decisión ya se ha cerrado.',
  not_eligible: 'Esta decisión no le corresponde a tu rol.',
  invalid_option: 'Esa opción no es válida.',
  already_decided: 'Ya habías tomado una decisión en este evento.',
  not_playing: 'La misión todavía no ha empezado.',
}

const CLOSED = {
  host_disconnected: 'La pantalla principal se ha desconectado.',
  game_finished: 'La misión ha terminado. ¡Gracias por jugar!',
}

export const errorText = (code) => ERRORS[code] ?? 'Ha ocurrido un error inesperado.'
export const rejectionText = (reason) => REJECTIONS[reason] ?? 'El centro de control ha rechazado la decisión.'
export const closedText = (reason) => CLOSED[reason] ?? 'La sala se ha cerrado.'
