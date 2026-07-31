import fp from 'fastify-plugin'
import type { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify'
import { config } from '../config/index.js'

export interface AuthUser {
  id: string
  email: string
  role: string
}

declare module 'fastify' {
  interface FastifyInstance {
    authenticate: (req: FastifyRequest, reply: FastifyReply) => Promise<void>
  }
  interface FastifyRequest {
    authUser: AuthUser
  }
}

async function verifySupabaseToken(token: string, supabaseUrl: string, anonKey: string): Promise<AuthUser> {
  const res = await fetch(`${supabaseUrl}/auth/v1/user`, {
    headers: {
      Authorization: `Bearer ${token}`,
      apikey: anonKey,
    },
  })

  if (!res.ok) {
    const body = await res.text()
    throw new Error(`Supabase auth rejected token: ${res.status} ${body}`)
  }

  const user = (await res.json()) as { id: string; email: string; role: string }
  return { id: user.id, email: user.email ?? '', role: user.role ?? 'authenticated' }
}

async function jwtAuthPlugin(app: FastifyInstance) {
  const supabaseUrl = config.SUPABASE_URL
  const supabaseAnonKey = config.SUPABASE_ANON_KEY

  if (!supabaseUrl || !supabaseAnonKey) {
    app.log.warn('SUPABASE_URL or SUPABASE_ANON_KEY not set — JWT auth disabled (dev mode only)')
    app.decorate('authenticate', async () => {})
    app.addHook('onRequest', async (req) => {
      req.authUser = { id: 'dev-user', email: 'dev@example.com', role: 'authenticated' }
    })
    return
  }

  app.decorate('authenticate', async (req: FastifyRequest, reply: FastifyReply) => {
    const header = req.headers.authorization
    if (!header?.startsWith('Bearer ')) {
      app.log.warn({ reqId: req.id }, 'Missing or malformed Authorization header')
      return reply.code(401).send({ error: 'Unauthorized' })
    }

    const token = header.slice(7)
    try {
      req.authUser = await verifySupabaseToken(token, supabaseUrl, supabaseAnonKey)
    } catch (err) {
      app.log.warn({ reqId: req.id, err }, 'JWT verification failed')
      return reply.code(401).send({ error: 'Unauthorized' })
    }
  })
}

export default fp(jwtAuthPlugin, { name: 'jwt-auth' })
