import { Injectable, Logger, NotFoundException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationDispatcherService } from '../notifications/notification-dispatcher.service';
import { TicketPriority, TicketStatus, UserRole, NotificationType } from '@prisma/client';

const SLA_DAYS: Record<TicketPriority, number> = {
  standard: 30,
  urgent: 10,
  critical: 1,
};

const STATUS_LABEL: Record<TicketStatus, string> = {
  open: 'Open',
  in_progress: 'In Progress',
  escalated: 'Escalated',
  resolved: 'Resolved',
  closed: 'Closed',
};

@Injectable()
export class TicketsService {
  private readonly logger = new Logger(TicketsService.name);

  constructor(
    private prisma: PrismaService,
    private dispatcher: NotificationDispatcherService,
  ) {}

  // ---------------------------------------------------------------------------
  // CREATE TICKET (member)
  // ---------------------------------------------------------------------------
  async create(userId: string, dto: {
    title: string;
    description?: string;
    categoryId?: string;
    priority?: TicketPriority;
  }) {
    this.logger.debug(`Creating ticket for userId: ${userId}, priority: ${dto.priority ?? 'standard'}`);

    const member = await this.prisma.member.findUnique({
      where: { userId },
      select: { id: true, districtId: true, workUnitId: true },
    });
    if (!member) {
      this.logger.warn(`Ticket creation failed — member not found for userId: ${userId}`);
      throw new NotFoundException('Member profile not found');
    }

    const priority = dto.priority ?? TicketPriority.standard;
    const slaDeadline = new Date();
    slaDeadline.setDate(slaDeadline.getDate() + SLA_DAYS[priority]);

    const ticket = await this.prisma.ticket.create({
      data: {
        memberId: member.id,
        title: dto.title,
        description: dto.description,
        categoryId: dto.categoryId,
        priority,
        status: TicketStatus.open,
        districtId: member.districtId,
        workUnitId: member.workUnitId,
        slaDeadline,
      },
      include: {
        category: { select: { name: true } },
      },
    });

    this.logger.log(`Ticket created — id: ${ticket.id}, priority: ${priority}, memberId: ${member.id}`);

    await this.notifyUser(userId, {
      notificationType: NotificationType.ticket_update,
      referenceId: ticket.id,
      title: 'Ticket Submitted',
      body: `Your ticket "${ticket.title}" (#${ticket.id.slice(-6).toUpperCase()}) has been received and will be reviewed shortly.`,
    });

    return ticket;
  }

  // ---------------------------------------------------------------------------
  // LIST TICKETS (scoped by role)
  // ---------------------------------------------------------------------------
  async findAll(
    userId: string,
    role: UserRole,
    filters: { status?: TicketStatus; page?: number; limit?: number },
  ) {
    const { status, page = 1, limit = 20 } = filters;
    const skip = (page - 1) * limit;

    let memberWhere = {};
    if (role === UserRole.member) {
      const member = await this.prisma.member.findUnique({
        where: { userId },
        select: { id: true },
      });
      memberWhere = { memberId: member?.id };
    }

    const repWhere = role === UserRole.rep ? { assignedRepId: userId } : {};

    const where = {
      ...memberWhere,
      ...repWhere,
      ...(status && { status }),
    };

    const [data, total] = await this.prisma.$transaction([
      this.prisma.ticket.findMany({
        where,
        skip,
        take: limit,
        include: {
          member: { select: { fullName: true, employeeId: true } },
          category: { select: { name: true } },
        },
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.ticket.count({ where }),
    ]);

    return { data, total, page, limit, totalPages: Math.ceil(total / limit) };
  }

  // ---------------------------------------------------------------------------
  // GET ONE TICKET
  // ---------------------------------------------------------------------------
  async findOne(id: string, userId: string, role: UserRole) {
    const ticket = await this.prisma.ticket.findUnique({
      where: { id },
      include: {
        member: { select: { fullName: true, employeeId: true, userId: true } },
        category: { select: { name: true } },
        comments: {
          where: role === UserRole.member ? { isInternal: false } : {},
          include: { user: { select: { employeeId: true, role: true } } },
          orderBy: { createdAt: 'asc' },
        },
        statusHistory: { orderBy: { changedAt: 'desc' } },
      },
    });

    if (!ticket) throw new NotFoundException(`Ticket ${id} not found`);

    if (role === UserRole.member && ticket.member.userId !== userId) {
      throw new ForbiddenException('Access denied');
    }

    return ticket;
  }

  // ---------------------------------------------------------------------------
  // ADD COMMENT
  // ---------------------------------------------------------------------------
  async addComment(
    ticketId: string,
    userId: string,
    role: UserRole,
    comment: string,
    isInternal = false,
  ) {
    if (isInternal && role === UserRole.member) {
      throw new ForbiddenException('Members cannot post internal comments');
    }

    const result = await this.prisma.ticketComment.create({
      data: { ticketId, userId, comment, isInternal },
      include: {
        ticket: {
          include: { member: { select: { userId: true } } },
        },
      },
    });

    // Notify the ticket owner when a rep/admin adds a public comment
    if (!isInternal && role !== UserRole.member) {
      const ownerId = result.ticket.member.userId;
      if (ownerId && ownerId !== userId) {
        await this.notifyUser(ownerId, {
          notificationType: NotificationType.ticket_update,
          referenceId: ticketId,
          title: 'New Reply on Your Ticket',
          body: `A union rep replied to your ticket "${result.ticket.title}".`,
        });
      }
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // UPDATE STATUS (rep / admin)
  // ---------------------------------------------------------------------------
  async updateStatus(
    ticketId: string,
    changedById: string,
    newStatus: TicketStatus,
    notes?: string,
  ) {
    const ticket = await this.prisma.ticket.findUniqueOrThrow({
      where: { id: ticketId },
      include: { member: { select: { userId: true } } },
    });

    await this.prisma.$transaction([
      this.prisma.ticketStatusHistory.create({
        data: {
          ticketId,
          changedById,
          oldStatus: ticket.status,
          newStatus,
          notes,
        },
      }),
      this.prisma.ticket.update({
        where: { id: ticketId },
        data: {
          status: newStatus,
          resolvedAt: newStatus === TicketStatus.resolved ? new Date() : undefined,
          updatedAt: new Date(),
        },
      }),
    ]);

    // Notify the ticket owner of the status change
    const ownerId = ticket.member.userId;
    if (ownerId && ownerId !== changedById) {
      const isCritical =
        newStatus === TicketStatus.resolved || newStatus === TicketStatus.escalated;
      await this.notifyUser(ownerId, {
        notificationType: NotificationType.ticket_update,
        referenceId: ticketId,
        title: 'Ticket Status Updated',
        body:
          `Your ticket "${ticket.title}" is now ${STATUS_LABEL[newStatus]}.` +
          (notes ? ` Note: ${notes}` : ''),
        isCritical,
      });
    }

    return { message: `Ticket status updated to ${newStatus}` };
  }

  // ---------------------------------------------------------------------------
  // Private: create notification record and dispatch
  // ---------------------------------------------------------------------------
  private async notifyUser(
    userId: string,
    opts: {
      notificationType: NotificationType;
      referenceId?: string;
      title: string;
      body: string;
      isUrgent?: boolean;
      isCritical?: boolean;
    },
  ): Promise<void> {
    try {
      const notification = await this.prisma.notification.create({
        data: {
          userId,
          type: opts.notificationType,
          title: opts.title,
          body: opts.body,
          referenceId: opts.referenceId,
          isUrgent: opts.isUrgent ?? false,
          isCritical: opts.isCritical ?? false,
        },
      });

      await this.dispatcher.dispatch({
        notificationId: notification.id,
        userId,
        title: opts.title,
        body: opts.body,
        isUrgent: opts.isUrgent,
        isCritical: opts.isCritical,
      });
    } catch (err) {
      console.error('Notification dispatch failed', err);
    }
  }
}
