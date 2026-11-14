const API_BASE_URL = 'http://localhost:29222/api'

async function request(path, options = {}) {
  const response = await fetch(`${API_BASE_URL}${path}`, {
    headers: {
      'Content-Type': 'application/json',
      ...options.headers,
    },
    ...options,
  })

  let payload = null
  try {
    payload = await response.json()
  } catch {
    payload = null
  }

  if (!response.ok) {
    throw new Error(payload?.error || `El servidor respondió con ${response.status}.`)
  }

  return payload
}

export function checkRoom(roomId) {
  return request(`/rooms/${encodeURIComponent(roomId)}`)
}

export function getQuestionOptions(roomId) {
  return request(`/rooms/${encodeURIComponent(roomId)}/question`)
}

export function sendAnswer(roomId, role, answer) {
  return request(`/rooms/${encodeURIComponent(roomId)}/answers`, {
    method: 'POST',
    body: JSON.stringify({ role, answer }),
  })
}

export function claimRole(roomId, role) {
  return request(`/rooms/${encodeURIComponent(roomId)}/roles/${encodeURIComponent(role)}`, {
    method: 'POST',
  })
}
