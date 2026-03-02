import { TicketStatus, UserRole } from '@prisma/client';
import { TicketsService } from './tickets.service';
export declare class TicketsController {
    private ticketsService;
    constructor(ticketsService: TicketsService);
    create(userId: string, body: any): Promise<{
        category: {
            name: string;
        } | null;
    } & {
        description: string | null;
        title: string;
        id: string;
        createdAt: Date;
        updatedAt: Date;
        districtId: string | null;
        workUnitId: string | null;
        memberId: string;
        priority: import("@prisma/client").$Enums.TicketPriority;
        status: import("@prisma/client").$Enums.TicketStatus;
        slaDeadline: Date;
        resolvedAt: Date | null;
        assignedRepId: string | null;
        assignedZonalOfficerId: string | null;
        categoryId: string | null;
    }>;
    findAll(userId: string, role: UserRole, query: any): Promise<{
        data: ({
            member: {
                employeeId: string;
                fullName: string;
            };
            category: {
                name: string;
            } | null;
        } & {
            description: string | null;
            title: string;
            id: string;
            createdAt: Date;
            updatedAt: Date;
            districtId: string | null;
            workUnitId: string | null;
            memberId: string;
            priority: import("@prisma/client").$Enums.TicketPriority;
            status: import("@prisma/client").$Enums.TicketStatus;
            slaDeadline: Date;
            resolvedAt: Date | null;
            assignedRepId: string | null;
            assignedZonalOfficerId: string | null;
            categoryId: string | null;
        })[];
        total: number;
        page: number;
        limit: number;
        totalPages: number;
    }>;
    findOne(id: string, userId: string, role: UserRole): Promise<{
        comments: ({
            user: {
                employeeId: string;
                role: import("@prisma/client").$Enums.UserRole;
            };
        } & {
            id: string;
            createdAt: Date;
            userId: string;
            isInternal: boolean;
            comment: string;
            ticketId: string;
        })[];
        member: {
            employeeId: string;
            userId: string;
            fullName: string;
        };
        category: {
            name: string;
        } | null;
        statusHistory: {
            id: string;
            changedById: string;
            notes: string | null;
            changedAt: Date;
            ticketId: string;
            oldStatus: import("@prisma/client").$Enums.TicketStatus;
            newStatus: import("@prisma/client").$Enums.TicketStatus;
        }[];
    } & {
        description: string | null;
        title: string;
        id: string;
        createdAt: Date;
        updatedAt: Date;
        districtId: string | null;
        workUnitId: string | null;
        memberId: string;
        priority: import("@prisma/client").$Enums.TicketPriority;
        status: import("@prisma/client").$Enums.TicketStatus;
        slaDeadline: Date;
        resolvedAt: Date | null;
        assignedRepId: string | null;
        assignedZonalOfficerId: string | null;
        categoryId: string | null;
    }>;
    addComment(id: string, userId: string, role: UserRole, body: {
        comment: string;
        isInternal?: boolean;
    }): Promise<{
        ticket: {
            member: {
                userId: string;
            };
        } & {
            description: string | null;
            title: string;
            id: string;
            createdAt: Date;
            updatedAt: Date;
            districtId: string | null;
            workUnitId: string | null;
            memberId: string;
            priority: import("@prisma/client").$Enums.TicketPriority;
            status: import("@prisma/client").$Enums.TicketStatus;
            slaDeadline: Date;
            resolvedAt: Date | null;
            assignedRepId: string | null;
            assignedZonalOfficerId: string | null;
            categoryId: string | null;
        };
    } & {
        id: string;
        createdAt: Date;
        userId: string;
        isInternal: boolean;
        comment: string;
        ticketId: string;
    }>;
    updateStatus(id: string, userId: string, body: {
        status: TicketStatus;
        notes?: string;
    }): Promise<{
        message: string;
    }>;
}
