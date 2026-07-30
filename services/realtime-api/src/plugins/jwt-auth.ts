import fp from 'fastify-plugin'
import fastifyJwt from '@fastify/jwt'
import type { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify'
import { config } from '../config/index.js'

export interface AuthUser {
  id: string    // Supabase user UUID (JWT 'sub' claim)
  email: string
  role: string
}

declare module '@fastify/jwt' {
  interface FastifyJWT {
    payload: {
      sub: string
      email: string
      role: string
      aud: string
      exp: number
    }
    user: AuthUser
  }
}

declare module 'fastify' {
  interface FastifyInstance {
    authenticate: (req: FastifyRequest, reply: FastifyReply) => Promise<void>
  }
  interface FastifyRequest {
    authUser: AuthUser
  }
}

async function jwtAuthPlugin(app: FastifyInstance) {
  if (!config.SUPABASE_JWT_SECRET) {
    app.log.warn('SUPABASE_JWT_SECRET not set — JWT auth disabled (dev mode only)')
    // Provide a no-op authenticate for dev convenience
    app.decorate('authenticate', async () => {})
    app.addHook('onRequest', async (req) => {
      req.authUser = { id: 'dev-user', email: 'dev@example.com', role: 'authenticated' }
    })
    return
  }

  await app.register(fastifyJwt, {
    secret: config.SUPABASE_JWT_SECRET,
    // Supabase JWTs target the "authenticated" audience
    verify: { allowedAud: 'authenticated' },
  })

  app.decorate('authenticate', async (req: FastifyRequest, reply: FastifyReply) => {
    try {
      const payload = await req.jwtVerify<{ sub: string; email: string; role: string }>()
      req.authUser = {
        id: payload.sub,
        email: payload.email,
        role: payload.role,
      }
    } catch {
      reply.code(401).send({ error: 'Unauthorized' })
    }
  })
}

export default fp(jwtAuthPlugin, { name: 'jwt-auth' })
