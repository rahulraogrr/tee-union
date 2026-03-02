import { NewsService } from './news.service';
export declare class NewsController {
    private newsService;
    constructor(newsService: NewsService);
    findAll(page?: string, limit?: string): Promise<{
        data: {
            id: string;
            titleEn: string;
            titleTe: string | null;
            publishedAt: Date | null;
            publishedBy: {
                employeeId: string;
            } | null;
        }[];
        total: number;
        page: number;
        limit: number;
        totalPages: number;
    }>;
    findOne(id: string): Promise<{
        id: string;
        createdAt: Date;
        updatedAt: Date;
        titleEn: string;
        titleTe: string | null;
        bodyEn: string;
        bodyTe: string | null;
        publishedById: string | null;
        isPublished: boolean;
        publishedAt: Date | null;
    }>;
    create(userId: string, body: any): Promise<{
        id: string;
        createdAt: Date;
        updatedAt: Date;
        titleEn: string;
        titleTe: string | null;
        bodyEn: string;
        bodyTe: string | null;
        publishedById: string | null;
        isPublished: boolean;
        publishedAt: Date | null;
    }>;
}
