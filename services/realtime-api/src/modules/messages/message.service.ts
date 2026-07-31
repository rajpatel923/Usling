import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()

export class MessageService {
  async send(senderId: string, pairId: string, content: string) {
    return prisma.message.create({
      data: { senderId, pairId, content },
    })
  }

  // All messages in this pair NOT sent by the given user (i.e. messages waiting to be read).
  async getPendingFor(userId: string, pairId: string) {
    return prisma.message.findMany({
      where: { pairId, senderId: { not: userId } },
      orderBy: { createdAt: 'asc' },
    })
  }

  // Hard-delete a message. Only the recipient (not the sender) may ack.
  async deleteOnAck(messageId: string, recipientId: string) {
    const msg = await prisma.message.findUnique({ where: { id: messageId } })
    if (!msg || msg.senderId === recipientId) return
    await prisma.message.delete({ where: { id: messageId } })
  }
}

export const messageService = new MessageService()
