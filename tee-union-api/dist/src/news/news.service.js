"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.NewsService = void 0;
const common_1 = require("@nestjs/common");
const prisma_service_1 = require("../prisma/prisma.service");
const notification_dispatcher_service_1 = require("../notifications/notification-dispatcher.service");
const client_1 = require("@prisma/client");
let NewsService = class NewsService {
    prisma;
    dispatcher;
    constructor(prisma, dispatcher) {
        this.prisma = prisma;
        this.dispatcher = dispatcher;
    }
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
    async findOne(id) {
        const news = await this.prisma.news.findFirst({
            where: { id, isPublished: true },
        });
        if (!news)
            throw new common_1.NotFoundException('News article not found');
        return news;
    }
    async create(publishedById, dto) {
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
            await this.broadcastToAllMembers(news.id, `\uD83D\uDCF0 ${dto.titleEn}`, 'A new news article has been published. Open the app to read it.');
        }
        return news;
    }
    async publish(id) {
        const news = await this.prisma.news.update({
            where: { id },
            data: { isPublished: true, publishedAt: new Date() },
        });
        await this.broadcastToAllMembers(news.id, `\uD83D\uDCF0 ${news.titleEn}`, 'A new news article has been published. Open the app to read it.');
    }
    async broadcastToAllMembers(newsId, title, body) {
        try {
            const users = await this.prisma.user.findMany({
                where: { isActive: true },
                select: { id: true },
            });
            const userIds = users.map((u) => u.id);
            if (userIds.length === 0)
                return;
            await this.dispatcher.broadcast(userIds, title, body, {
                type: client_1.NotificationType.news,
                referenceId: newsId,
            });
        }
        catch (err) {
            console.error('News broadcast failed', err);
        }
    }
};
exports.NewsService = NewsService;
exports.NewsService = NewsService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService,
        notification_dispatcher_service_1.NotificationDispatcherService])
], NewsService);
//# sourceMappingURL=news.service.js.map