import { PrismaClient } from '@prisma/client'
import { customAlphabet } from 'nanoid'

const prisma = new PrismaClient()

// URL-safe alphabet without easily-confused characters
const generateCode = customAlphabet('23456789ABCDEFGHJKLMNPQRSTUVWXYZ', 6)

const INVITE_TTL_MS = 7 * 24 * 60 * 60 * 1000  // 7 days

export class PairingService {
  /** Upserts a Profile row for the authenticated user (idempotent). */
  async ensureProfile(userId: string, email: string) {
    return prisma.profile.upsert({
      where: { id: userId },
      update: {},
      create: { id: userId, email },
    })
  }

  /** Creates a new invite code for the user. Revokes any prior pending invite. */
  async createInvite(userId: string): Promise<string> {
    // Revoke any unused, non-expired invites the user already has
    await prisma.invite.updateMany({
      where: { creatorId: userId, usedAt: null, expiresAt: { gt: new Date() } },
      data: { expiresAt: new Date() },
    })

    const code = generateCode()
    await prisma.invite.create({
      data: {
        code,
        creatorId: userId,
        expiresAt: new Date(Date.now() + INVITE_TTL_MS),
      },
    })
    return code
  }

  /**
   * Accepts an invite and creates a Pair between inviter and accepter.
   * Returns the pairId or throws a descriptive error.
   */
  async acceptInvite(code: string, accepterId: string): Promise<string> {
    const invite = await prisma.invite.findUnique({ where: { code } })

    if (!invite)           throw Object.assign(new Error('Invite not found'), { status: 404 })
    if (invite.usedAt)     throw Object.assign(new Error('Invite already used'), { status: 409 })
    if (invite.expiresAt < new Date()) throw Object.assign(new Error('Invite expired'), { status: 410 })
    if (invite.creatorId === accepterId) throw Object.assign(new Error('Cannot accept your own invite'), { status: 422 })

    // Check neither user is already in a pair
    const existing = await prisma.pairMember.findFirst({
      where: { userId: { in: [invite.creatorId, accepterId] } },
    })
    if (existing) throw Object.assign(new Error('One or both users are already paired'), { status: 409 })

    const pair = await prisma.$transaction(async (tx) => {
      const newPair = await tx.pair.create({ data: {} })
      await tx.pairMember.createMany({
        data: [
          { pairId: newPair.id, userId: invite.creatorId },
          { pairId: newPair.id, userId: accepterId },
        ],
      })
      await tx.invite.update({
        where: { code },
        data: { usedAt: new Date(), pairId: newPair.id },
      })
      return newPair
    })

    return pair.id
  }

  /** Returns the pairId for a user, or null if they're unpaired. */
  async getPairId(userId: string): Promise<string | null> {
    const member = await prisma.pairMember.findUnique({ where: { userId } })
    return member?.pairId ?? null
  }
}

export const pairingService = new PairingService()
