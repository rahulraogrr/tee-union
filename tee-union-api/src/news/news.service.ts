import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationDispatcherService } from '../notifications/notification-dispatcher.service';
import { NotificationType } from '@prisma/client';

@Injectable()
export class NewsService {
  private readonly logger = new Logger(NewsService.name);

  constructor(
    private prisma: PrismaService,
    private dispatcher: NotificationDispatcherService,
  ) {}

  async findAll(page = 1, limit = 20) {
    const skip = (page - 1) * limit;
    const [data, total] = await this.prisma.$transaction([
      this.prisma.news.findMany({
        where: { isPublished: true },
        skip,
        take: limit,
        orderBy: { publishedAt: 'desc' },
        select: {
          id: true, titleEn: true, titleTe: true,
          publishedAt: true, publishedBy: { select: { employeeId: true } },
        },
      }),
      this.prisma.news.count({ where: { isPublished: true } }),
    ]);
    return { data, total, page, limit, totalPages: Math.ceil(total / limit) };
  }

  async findOne(id: string) {
    const news = await this.prisma.news.findFirst({
      where: { id, isPublished: true },
    });
    if (!news) throw new NotFoundException('News article not found');
    return news;
  }

  async create(publishedById: string, dto: {
    titleEn: string; titleTe?: string;
    bodyEn: string; bodyTe?: string;
    publish?: boolean;
  }) {
    const news = await this.prisma.news.create({
      data: {
        titleEn: dto.titleEn,
        titleTe: dto.titleTe,
        bodyEn: dto.bodyEn,
        bodyTe: dto.bodyTe,
        publishedById,
        isPublished: dto.publish ?? false,
        publishedAt: dto.publish ? new Date() : null,
      },
    });

    if (dto.publish) {
      await this.broadcastToAllMembers(
        news.id,
        `\uD83D\uDCF0 ${dto.titleEn}`,
        'A new news article has been published. Open the app to read it.',
      );
    }

    return news;
  }

  async publish(id: string): Promise<void> {
    const news = await this.prisma.news.update({
      where: { id },
      data: { isPublished: true, publishedAt: new Date() },
    });

    await this.broadcastToAllMembers(
      news.id,
      `\uD83D\uDCF0 ${news.titleEn}`,
      'A new news article has been published. Open the app to read it.',
    );
  }

  private async broadcastToAllMembers(
    newsId: string,
    title: string,
    body: string,
  ): Promise<void> {
    try {
      const users = await this.prisma.user.findMany({
        where: { isActive: true },
        select: { id: true },
      });

      const userIds = users.map((u) => u.id);
      if (userIds.length === 0) return;

      await this.dispatcher.broadcast(userIds, title, body, {
        type: NotificationType.news,
        referenceId: newsId,
      });
    } catch (err) {
      console.error('News broadcast failed', err);
    }
  }
}
