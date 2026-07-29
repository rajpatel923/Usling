import { buildApp } from './app.js'
import { config } from './config/index.js'

const app = await buildApp()

try {
  await app.listen({ host: config.HTTP_HOST, port: config.HTTP_PORT })
} catch (err) {
  app.log.error(err)
  process.exit(1)
}
