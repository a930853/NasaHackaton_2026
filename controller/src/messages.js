// Textos de interfaz para los códigos del contrato (docs/es/protocol.md). En inglés sencillo, como el juego.

const ERRORS = {
  offline: 'No connection to Mission Control. Try again in a few seconds.',
  invalid_code: 'Type a valid room code.',
  invalid_name: 'Type your name (24 letters at most).',
  room_not_found: 'That room does not exist or is already closed. Check the code on the main screen.',
  room_full: 'This room already has four crew members.',
  game_already_started: 'The mission in that room has already started.',
  invalid_token: 'Your old session has expired. Please join again.',
  role_taken: 'That role is taken. Pick another one.',
  not_in_lobby: 'The mission has started: you cannot change roles now.',
  not_playing: 'The mission has not started yet.',
}

const REJECTIONS = {
  event_closed: 'This decision is already closed.',
  not_eligible: 'This decision is not for your role.',
  invalid_option: 'That option is not valid.',
  already_decided: 'You already voted in this event.',
  not_playing: 'The mission has not started yet.',
}

const CLOSED = {
  host_disconnected: 'The main screen got disconnected.',
  game_finished: 'The mission is over. Thanks for playing!',
}

export const errorText = (code) => ERRORS[code] ?? 'Something went wrong.'
export const rejectionText = (reason) => REJECTIONS[reason] ?? 'Mission Control did not accept that choice.'
export const closedText = (reason) => CLOSED[reason] ?? 'The room is closed.'
