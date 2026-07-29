export async function registerHealthRoutes(app) {
    app.get('/health', async () => ({
        status: 'ok',
        version: 1,
        timestamp: new Date().toISOString(),
    }));
}
