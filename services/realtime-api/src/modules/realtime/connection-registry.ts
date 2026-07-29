import type { WebSocket } from '@fastify/websocket'

export interface ConnectionMeta {
  pairId: string
  userId: string
  characterId: string
  socket: WebSocket
}

/**
 * In-memory registry of active WebSocket connections per pair.
 * For a single backend instance — no Redis required until horizontal scaling.
 */
export class ConnectionRegistry {
  // pairId → userId → Set of active sockets
  private readonly pairs = new Map<string, Map<string, Set<WebSocket>>>()
  // socket → metadata for fast lookup on message/close
  private readonly meta = new Map<WebSocket, ConnectionMeta>()

  register(conn: ConnectionMeta): void {
    const { pairId, userId, socket } = conn
    if (!this.pairs.has(pairId)) {
      this.pairs.set(pairId, new Map())
    }
    const users = this.pairs.get(pairId)!
    if (!users.has(userId)) {
      users.set(userId, new Set())
    }
    users.get(userId)!.add(socket)
    this.meta.set(socket, conn)
  }

  unregister(socket: WebSocket): void {
    const conn = this.meta.get(socket)
    if (!conn) return
    const { pairId, userId } = conn
    this.pairs.get(pairId)?.get(userId)?.delete(socket)
    this.meta.delete(socket)
  }

  getMeta(socket: WebSocket): ConnectionMeta | undefined {
    return this.meta.get(socket)
  }

  /** Returns all sockets in the pair that belong to the other user. */
  getPartnerSockets(pairId: string, senderId: string): WebSocket[] {
    const users = this.pairs.get(pairId)
    if (!users) return []
    const result: WebSocket[] = []
    for (const [userId, sockets] of users) {
      if (userId !== senderId) {
        result.push(...sockets)
      }
    }
    return result
  }
}
