import Fastify from 'fastify'
import fastifyWebsocket from '@fastify/websocket'
import { config } from './config/index.js'
import { registerHealthRoutes } from './modules/health/health.routes.js'
import { registerRealtimeRoutes } from './modules/realtime/realtime.handler.js'

export async function buildApp() {
  const app = Fastify({
    logger: {
      level: config.LOG_LEVEL,
      redact: ['req.headers.authorization'],
    },
  })

  await app.register(fastifyWebsocket)

  await app.register(registerHealthRoutes)
  await app.register(registerRealtimeRoutes)

  return app
}
