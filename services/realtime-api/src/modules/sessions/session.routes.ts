import type { FastifyInstance } from 'fastify'
import { pairingService } from '../pairing/pairing.service.js'
import { config } from '../../config/index.js'

/**
 * Returns WebSocket connection metadata for the authenticated user.
 * The client calls this first, then opens the WebSocket with the returned wsUrl.
 */
export async function registerSessionRoutes(app: FastifyInstance) {
  app.post('/session', { preHandler: [app.authenticate] }, async (req, reply) => {
    const user = req.authUser
    const pairId = await pairingService.getPairId(user.id)

    if (!pairId) {
      return reply.code(403).send({ error: 'Not paired. Accept an invite first.' })
    }

    const wsProto = config.APP_ENV === 'production' ? 'wss' : 'ws'
    const wsHost = `${config.HTTP_HOST === '0.0.0.0' ? 'localhost' : config.HTTP_HOST}:${config.HTTP_PORT}`
    const wsUrl = `${wsProto}://${wsHost}/ws`

    return reply.send({
      userId: user.id,
      pairId,
      wsUrl,
      // Client should reconnect 5 minutes before this to refresh
      expiresIn: 3600,
    })
  })
}
