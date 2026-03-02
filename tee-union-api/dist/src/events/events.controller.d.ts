import { EventsService } from './events.service';
export declare class EventsController {
    private eventsService;
    constructor(eventsService: EventsService);
    findAll(districtId?: string, page?: string, limit?: string): Promise<{
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
    create(userId: string, body: any): Promise<{
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
}
