import { Injectable, Logger, NotFoundException, ConflictException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationDispatcherService } from '../notifications/notification-dispatcher.service';
import { NotificationType } from '@prisma/client';

@Injectable()
export class EventsService {
  private readonly logger = new Logger(EventsService.name);

  constructor(
    private prisma: PrismaService,
    private dispatcher: NotificationDispatcherService,
  ) {}

  async findAll(districtId?: string, page = 1, limit = 20) {
    const skip = (page - 1) * limit;
    const where = {
      isPublished: true,
      eventDate: { gte: new Date() },
      ...(districtId && {
        OR: [{ districtId }, { districtId: null }],
      }),
    };

    const [data, total] = await this.prisma.$transaction([
      this.prisma.event.findMany({
        where,
        skip,
        take: limit,
        orderBy: { eventDate: 'asc' },
        select: {
          id: true, titleEn: true, titleTe: true,
          eventDate: true, location: true, isVirtual: true,
          maxCapacity: true, district: { select: { name: true } },
          _count: { select: { registrations: true } },
        },
      }),
      this.prisma.event.count({ where }),
    ]);

    return { data, total, page, limit, totalPages: Math.ceil(total / limit) };
  }

  async findOne(id: string) {
    const event = await this.prisma.event.findFirst({
      where: { id, isPublished: true },
      include: {
        district: { select: { name: true } },
        _count: { select: { registrations: true } },
      },
    });
    if (!event) throw new NotFoundException('Event not found');
    return event;
  }

  async register(eventId: string, userId: string) {
    const member = await this.prisma.member.findUnique({
      where: { userId },
      select: { id: true },
    });
    if (!member) throw new NotFoundException('Member profile not found');

    const event = await this.prisma.event.findUniqueOrThrow({ where: { id: eventId } });

    if (event.maxCapacity) {
      const count = await this.prisma.eventRegistration.count({ where: { eventId } });
      if (count >= event.maxCapacity) {
        throw new ConflictException('Event is at full capacity');
      }
    }

    try {
      const registration = await this.prisma.eventRegistration.create({
        data: { eventId, memberId: member.id },
      });

      await this.notifyUser(userId, {
        type: NotificationType.event,
        referenceId: eventId,
        title: 'Event Registration Confirmed',
        body: `You are registered for "${event.titleEn}" on ${new Date(event.eventDate).toLocaleDateString('en-IN', { dateStyle: 'long' })}.`,
      });

      return registration;
    } catch {
      throw new ConflictException('You are already registered for this event');
    }
  }

  async create(createdById: string, dto: {
    titleEn: string; titleTe?: string;
    descriptionEn?: string; descriptionTe?: string;
    eventDate: Date; location?: string;
    maxCapacity?: number; isVirtual?: boolean;
    districtId?: string; publish?: boolean;
  }) {
    const event = await this.prisma.event.create({
      data: {
        titleEn: dto.titleEn, titleTe: dto.titleTe,
        descriptionEn: dto.descriptionEn, descriptionTe: dto.descriptionTe,
        eventDate: dto.eventDate, location: dto.location,
        maxCapacity: dto.maxCapacity,
        isVirtual: dto.isVirtual ?? false,
        districtId: dto.districtId,
        createdById,
        isPublished: dto.publish ?? false,
      },
    });

    if (dto.publish) {
      const dateStr = new Date(dto.eventDate).toLocaleDateString('en-IN', { dateStyle: 'long' });
      const loc = dto.location ? ` at ${dto.location}` : '';
      const body = `Join us on ${dateStr}${loc}. Open the app to register.`;

      const users = await this.prisma.user.findMany({
        where: {
          isActive: true,
          ...(dto.districtId
            ? { member: { districtId: dto.districtId } }
            : {}),
        },
        select: { id: true },
      });

      const userIds = users.map((u) => u.id);
      if (userIds.length > 0) {
        await this.dispatcher
          .broadcast(userIds, `\uD83D\uDCC5 ${dto.titleEn}`, body, {
            type: NotificationType.event,
            referenceId: event.id,
          })
          .catch((err) => console.error('Event broadcast failed', err));
      }
    }

    return event;
  }

  private async notifyUser(
    userId: string,
    opts: { type: NotificationType; referenceId?: string; title: string; body: string },
  ): Promise<void> {
    try {
      const notification = await this.prisma.notification.create({
        data: {
          userId,
          type: opts.type,
          title: opts.title,
          body: opts.body,
          referenceId: opts.referenceId,
        },
      });

      await this.dispatcher.dispatch({
        notificationId: notification.id,
        userId,
        title: opts.title,
        body: opts.body,
      });
    } catch (err) {
      console.error('Event notification dispatch failed', err);
    }
  }
}
