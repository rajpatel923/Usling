const DEFAULT_PAIR_ID = 'mypair'
const DEFAULT_BASE_URL = 'ws://localhost:3000/ws'
const CLOSE_TIMEOUT_MS = 1500

const pairId = process.env.PAIR_ID ?? DEFAULT_PAIR_ID
const userA = process.env.USER_A ?? 'user-a'
const userB = process.env.USER_B ?? 'user-b'
const characterA = process.env.CHARACTER_A ?? 'char-a'
const characterB = process.env.CHARACTER_B ?? 'char-b'
const baseUrl = process.env.WS_URL ?? DEFAULT_BASE_URL

const urlA = withToken(baseUrl, `${pairId}:${userA}:${characterA}`)
const urlB = withToken(baseUrl, `${pairId}:${userB}:${characterB}`)

const [sender, receiver] = await Promise.all([connect(urlA), connect(urlB)])

const event = {
  version: 1,
  type: 'presence.updated',
  eventId: crypto.randomUUID(),
  pairId,
  actorId: userA,
  deviceId: 'ws-smoke',
  sequence: 1,
  sentAt: new Date().toISOString(),
  payload: { state: 'active' },
}

const received = waitForJsonMessage(receiver)
sender.send(JSON.stringify(event))

try {
  const message = await received
  console.log(JSON.stringify(message, null, 2))
} finally {
  sender.close()
  receiver.close()
}

function withToken(base, token) {
  const url = new URL(base)
  url.searchParams.set('token', token)
  return url
}

function connect(url) {
  return new Promise((resolve, reject) => {
    const socket = new WebSocket(url)
    const timeout = setTimeout(() => {
      socket.close()
      reject(new Error(`Timed out connecting to ${redactToken(url)}`))
    }, CLOSE_TIMEOUT_MS)

    socket.addEventListener(
      'open',
      () => {
        clearTimeout(timeout)
        resolve(socket)
      },
      { once: true },
    )
    socket.addEventListener(
      'error',
      () => {
        clearTimeout(timeout)
        reject(new Error(`Failed to connect to ${redactToken(url)}`))
      },
      { once: true },
    )
  })
}

function waitForJsonMessage(socket) {
  return new Promise((resolve, reject) => {
    const timeout = setTimeout(() => {
      reject(new Error('Timed out waiting for partner event'))
    }, CLOSE_TIMEOUT_MS)

    socket.addEventListener(
      'message',
      (event) => {
        clearTimeout(timeout)
        try {
          resolve(JSON.parse(event.data))
        } catch (error) {
          reject(error)
        }
      },
      { once: true },
    )
  })
}

function redactToken(url) {
  const copy = new URL(url)
  copy.searchParams.set('token', '<redacted>')
  return copy.toString()
}
