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
exports.EventsService = void 0;
const common_1 = require("@nestjs/common");
const prisma_service_1 = require("../prisma/prisma.service");
const notification_dispatcher_service_1 = require("../notifications/notification-dispatcher.service");
const client_1 = require("@prisma/client");
let EventsService = class EventsService {
    prisma;
    dispatcher;
    constructor(prisma, dispatcher) {
        this.prisma = prisma;
        this.dispatcher = dispatcher;
    }
    async findAll(districtId, page = 1, limit = 20) {
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
    async findOne(id) {
        const event = await this.prisma.event.findFirst({
            where: { id, isPublished: true },
            include: {
                district: { select: { name: true } },
                _count: { select: { registrations: true } },
            },
        });
        if (!event)
            throw new common_1.NotFoundException('Event not found');
        return event;
    }
    async register(eventId, userId) {
        const member = await this.prisma.member.findUnique({
            where: { userId },
            select: { id: true },
        });
        if (!member)
            throw new common_1.NotFoundException('Member profile not found');
        const event = await this.prisma.event.findUniqueOrThrow({ where: { id: eventId } });
        if (event.maxCapacity) {
            const count = await this.prisma.eventRegistration.count({ where: { eventId } });
            if (count >= event.maxCapacity) {
                throw new common_1.ConflictException('Event is at full capacity');
            }
        }
        try {
            const registration = await this.prisma.eventRegistration.create({
                data: { eventId, memberId: member.id },
            });
            await this.notifyUser(userId, {
                type: client_1.NotificationType.event,
                referenceId: eventId,
                title: 'Event Registration Confirmed',
                body: `You are registered for "${event.titleEn}" on ${new Date(event.eventDate).toLocaleDateString('en-IN', { dateStyle: 'long' })}.`,
            });
            return registration;
        }
        catch {
            throw new common_1.ConflictException('You are already registered for this event');
        }
    }
    async create(createdById, dto) {
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
                    type: client_1.NotificationType.event,
                    referenceId: event.id,
                })
                    .catch((err) => console.error('Event broadcast failed', err));
            }
        }
        return event;
    }
    async notifyUser(userId, opts) {
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
        }
        catch (err) {
            console.error('Event notification dispatch failed', err);
        }
    }
};
exports.EventsService = EventsService;
exports.EventsService = EventsService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService,
        notification_dispatcher_service_1.NotificationDispatcherService])
], EventsService);
//# sourceMappingURL=events.service.js.map