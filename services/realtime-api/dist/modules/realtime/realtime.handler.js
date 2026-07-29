import { parseEvent } from '../../protocol/events.js';
import { ConnectionRegistry } from './connection-registry.js';
import { validateOwnership } from './ownership-validator.js';
const registry = new ConnectionRegistry();
/**
 * Dev-mode token format: "pairId:userId:characterId"
 * Week 5+ will replace this with real JWT authentication.
 */
function parseDevToken(token) {
    const parts = token.split(':');
    if (parts.length !== 3)
        return null;
    const [pairId, userId, characterId] = parts;
    if (!pairId || !userId || !characterId)
        return null;
    return { pairId, userId, characterId };
}
function sendError(socket, code, message) {
    const errorEvent = JSON.stringify({
        version: 1,
        type: 'error',
        payload: { code, message },
    });
    if (socket.readyState === socket.OPEN) {
        socket.send(errorEvent);
    }
}
export async function registerRealtimeRoutes(app) {
    app.get('/ws', { websocket: true }, (socket, request) => {
        // Parse dev auth token from query string
        const token = request.query['token'] ?? '';
        const auth = parseDevToken(token);
        if (!auth) {
            sendError(socket, 'AUTH_REQUIRED', 'Valid token query parameter required');
            socket.close(1008, 'Unauthorized');
            return;
        }
        const conn = { ...auth, socket };
        registry.register(conn);
        app.log.info({ pairId: auth.pairId, userId: auth.userId }, 'ws:connected');
        socket.on('message', (raw) => {
            let parsed;
            try {
                parsed = JSON.parse(raw.toString());
            }
            catch {
                sendError(socket, 'INVALID_JSON', 'Message must be valid JSON');
                return;
            }
            const result = parseEvent(parsed);
            if (!result.ok) {
                app.log.warn({ error: result.error }, 'ws:parse_error');
                sendError(socket, result.error, 'Event validation failed');
                return;
            }
            const envelope = result.data;
            // Ownership check for movement events
            if (!validateOwnership(envelope, conn)) {
                app.log.warn({ type: envelope.type, userId: conn.userId }, 'ws:ownership_violation');
                sendError(socket, 'OWNERSHIP_VIOLATION', 'You do not own that character');
                return;
            }
            // Relay to partner(s)
            const partnerSockets = registry.getPartnerSockets(conn.pairId, conn.userId);
            const outgoing = JSON.stringify(parsed);
            for (const partnerSocket of partnerSockets) {
                if (partnerSocket.readyState === partnerSocket.OPEN) {
                    partnerSocket.send(outgoing);
                }
            }
            app.log.debug({ type: envelope.type, relayed: partnerSockets.length }, 'ws:relayed');
        });
        socket.on('close', () => {
            registry.unregister(socket);
            app.log.info({ userId: conn.userId }, 'ws:disconnected');
        });
        socket.on('error', (err) => {
            app.log.error({ err, userId: conn.userId }, 'ws:error');
            registry.unregister(socket);
        });
    });
}
