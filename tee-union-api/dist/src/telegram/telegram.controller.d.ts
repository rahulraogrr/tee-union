import { ConfigService } from '@nestjs/config';
import { TelegramLinkService } from './telegram-link.service';
export declare class TelegramController {
    private readonly linkService;
    private readonly config;
    private readonly logger;
    constructor(linkService: TelegramLinkService, config: ConfigService);
    handleWebhook(body: Record<string, unknown>, secret: string): Promise<{
        ok: boolean;
    }>;
    generateLinkToken(user: {
        id: string;
    }): Promise<{
        token: string;
        instructions: string;
    }>;
    unlinkTelegram(user: {
        id: string;
    }): Promise<{
        ok: boolean;
    }>;
    getLinkStatus(user: {
        id: string;
        telegramChatId?: bigint | null;
    }): Promise<{
        linked: boolean;
        linkedAt?: Date | null;
    }>;
}
