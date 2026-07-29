/**
 * In-memory registry of active WebSocket connections per pair.
 * For a single backend instance — no Redis required until horizontal scaling.
 */
export class ConnectionRegistry {
    // pairId → userId → Set of active sockets
    pairs = new Map();
    // socket → metadata for fast lookup on message/close
    meta = new Map();
    register(conn) {
        const { pairId, userId, socket } = conn;
        if (!this.pairs.has(pairId)) {
            this.pairs.set(pairId, new Map());
        }
        const users = this.pairs.get(pairId);
        if (!users.has(userId)) {
            users.set(userId, new Set());
        }
        users.get(userId).add(socket);
        this.meta.set(socket, conn);
    }
    unregister(socket) {
        const conn = this.meta.get(socket);
        if (!conn)
            return;
        const { pairId, userId } = conn;
        this.pairs.get(pairId)?.get(userId)?.delete(socket);
        this.meta.delete(socket);
    }
    getMeta(socket) {
        return this.meta.get(socket);
    }
    /** Returns all sockets in the pair that belong to the other user. */
    getPartnerSockets(pairId, senderId) {
        const users = this.pairs.get(pairId);
        if (!users)
            return [];
        const result = [];
        for (const [userId, sockets] of users) {
            if (userId !== senderId) {
                result.push(...sockets);
            }
        }
        return result;
    }
}
