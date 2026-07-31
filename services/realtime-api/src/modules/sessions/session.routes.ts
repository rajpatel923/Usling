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
    const wsProto = config.APP_ENV === 'production' ? 'wss' : 'ws'
    const wsHost = `${config.HTTP_HOST === '0.0.0.0' ? 'localhost' : config.HTTP_HOST}:${config.HTTP_PORT}`

    // Dev bypass: skip DB when DATABASE_URL is missing or clearly invalid (no valid host)
    const dbReady = config.DATABASE_URL?.includes('.pooler.supabase.com') || config.DATABASE_URL?.includes('localhost')
    if (config.APP_ENV === 'development' && !dbReady) {
      const pairId = 'dev-pair-1'
      return reply.send({
        userId: user.id,
        pairId,
        wsUrl: `${wsProto}://${wsHost}/ws?devPairId=${pairId}`,
        expiresIn: 3600,
      })
    }

    const pairId = await pairingService.getPairId(user.id)
    if (!pairId) {
      return reply.code(403).send({ error: 'Not paired. Accept an invite first.' })
    }

    return reply.send({
      userId: user.id,
      pairId,
      wsUrl: `${wsProto}://${wsHost}/ws`,
      expiresIn: 3600,
    })
  })
}
