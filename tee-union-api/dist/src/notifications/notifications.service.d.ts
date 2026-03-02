import { PrismaService } from '../prisma/prisma.service';
export declare class NotificationsService {
    private prisma;
    constructor(prisma: PrismaService);
    findForUser(userId: string, options: {
        page: number;
        limit: number;
        unreadOnly?: boolean;
    }): Promise<{
        data: {
            type: import("@prisma/client").$Enums.NotificationType;
            title: string;
            id: string;
            body: string;
            isUrgent: boolean;
            isCritical: boolean;
            referenceId: string | null;
            isRead: boolean;
            sentAt: Date;
            readAt: Date | null;
        }[];
        meta: {
            total: number;
            page: number;
            limit: number;
            pages: number;
        };
    }>;
    getUnreadCount(userId: string): Promise<{
        count: number;
    }>;
    markAllReadForUser(userId: string): Promise<void>;
}
