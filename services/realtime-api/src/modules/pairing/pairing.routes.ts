import type { FastifyInstance } from 'fastify'
import { z } from 'zod'
import { pairingService } from './pairing.service.js'

const CreateInviteResponse = z.object({ code: z.string() })
const AcceptInviteBody = z.object({ code: z.string().length(6) })
const AcceptInviteResponse = z.object({ pairId: z.string() })
const StatusResponse = z.object({ pairId: z.string().nullable() })

export async function registerPairingRoutes(app: FastifyInstance) {
  // All pairing routes require a valid Supabase JWT
  const preHandler = [app.authenticate]

  /** Generate a single-use invite code for the authenticated user. */
  app.post('/pair/invite', { preHandler }, async (req, reply) => {
    const user = req.authUser
    await pairingService.ensureProfile(user.id, user.email)
    const code = await pairingService.createInvite(user.id)
    return reply.code(201).send({ code })
  })

  /** Accept a partner's invite code and form a pair. */
  app.post('/pair/accept', { preHandler }, async (req, reply) => {
    const user = req.authUser
    await pairingService.ensureProfile(user.id, user.email)

    const body = AcceptInviteBody.safeParse(req.body)
    if (!body.success) return reply.code(400).send({ error: 'code must be 6 characters' })

    try {
      const pairId = await pairingService.acceptInvite(body.data.code, user.id)
      return reply.code(201).send({ pairId })
    } catch (err: any) {
      return reply.code(err.status ?? 500).send({ error: err.message })
    }
  })

  /** Return the caller's current pair status (null if unpaired). */
  app.get('/pair/status', { preHandler }, async (req, reply) => {
    const pairId = await pairingService.getPairId(req.authUser.id)
    return reply.send({ pairId })
  })
}
