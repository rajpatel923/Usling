import Fastify from 'fastify'
import fastifyWebsocket from '@fastify/websocket'
import { config } from './config/index.js'
import { registerHealthRoutes } from './modules/health/health.routes.js'
import { registerRealtimeRoutes } from './modules/realtime/realtime.handler.js'
import { registerPairingRoutes } from './modules/pairing/pairing.routes.js'
import { registerSessionRoutes } from './modules/sessions/session.routes.js'
import { registerMessageRoutes } from './modules/messages/message.routes.js'
import jwtAuthPlugin from './plugins/jwt-auth.js'

export async function buildApp() {
  const app = Fastify({
    logger: {
      level: config.LOG_LEVEL,
      redact: ['req.headers.authorization'],
    },
  })

  await app.register(fastifyWebsocket)
  await app.register(jwtAuthPlugin)

  await app.register(registerHealthRoutes)
  await app.register(registerPairingRoutes)
  await app.register(registerSessionRoutes)
  await app.register(registerRealtimeRoutes)
  await app.register(registerMessageRoutes)

  return app
}
