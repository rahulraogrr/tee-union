import { PrismaService } from '../prisma/prisma.service';
import { NotificationDispatcherService } from '../notifications/notification-dispatcher.service';
export declare class EventsService {
    private prisma;
    private dispatcher;
    constructor(prisma: PrismaService, dispatcher: NotificationDispatcherService);
    findAll(districtId?: string, page?: number, limit?: number): Promise<{
        data: {
            district: {
                name: string;
            } | null;
            id: string;
            _count: {
                registrations: number;
            };
            titleEn: string;
            titleTe: string | null;
            eventDate: Date;
            location: string | null;
            maxCapacity: number | null;
            isVirtual: boolean;
        }[];
        total: number;
        page: number;
        limit: number;
        totalPages: number;
    }>;
    findOne(id: string): Promise<{
        district: {
            name: string;
        } | null;
        _count: {
            registrations: number;
        };
    } & {
        id: string;
        createdById: string | null;
        createdAt: Date;
        updatedAt: Date;
        districtId: string | null;
        titleEn: string;
        titleTe: string | null;
        isPublished: boolean;
        descriptionEn: string | null;
        descriptionTe: string | null;
        eventDate: Date;
        location: string | null;
        maxCapacity: number | null;
        isVirtual: boolean;
    }>;
    register(eventId: string, userId: string): Promise<{
        id: string;
        memberId: string;
        eventId: string;
        registeredAt: Date;
    }>;
    create(createdById: string, dto: {
        titleEn: string;
        titleTe?: string;
        descriptionEn?: string;
        descriptionTe?: string;
        eventDate: Date;
        location?: string;
        maxCapacity?: number;
        isVirtual?: boolean;
        districtId?: string;
        publish?: boolean;
    }): Promise<{
        id: string;
        createdById: string | null;
        createdAt: Date;
        updatedAt: Date;
        districtId: string | null;
        titleEn: string;
        titleTe: string | null;
        isPublished: boolean;
        descriptionEn: string | null;
        descriptionTe: string | null;
        eventDate: Date;
        location: string | null;
        maxCapacity: number | null;
        isVirtual: boolean;
    }>;
    private notifyUser;
}
