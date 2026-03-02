import {
  Controller,
  Post,
  Body,
  Headers,
  HttpCode,
  HttpStatus,
  Logger,
  UnauthorizedException,
  Get,
} from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { ConfigService } from '@nestjs/config';
import { Public } from '../common/decorators/public.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { TelegramLinkService } from './telegram-link.service';
import * as crypto from 'crypto';

@ApiTags('telegram')
@Controller('telegram')
export class TelegramController {
  private readonly logger = new Logger(TelegramController.name);

  constructor(
    private readonly linkService: TelegramLinkService,
    private readonly config: ConfigService,
  ) {}

  // ---------------------------------------------------------------------------
  // Webhook — receives updates from Telegram servers (production only)
  // ---------------------------------------------------------------------------
  @Public()
  @Post('webhook')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Telegram webhook (called by Telegram servers)' })
  async handleWebhook(
    @Body() body: Record<string, unknown>,
    @Headers('x-telegram-bot-api-secret-token') secret: string,
  ): Promise<{ ok: boolean }> {
    const expectedSecret = this.config.get<string>('TELEGRAM_WEBHOOK_SECRET');

    if (expectedSecret) {
      const expected = crypto
        .createHmac('sha256', expectedSecret)
        .update(JSON.stringify(body))
        .digest('hex');

      if (secret !== expected) {
        this.logger.warn('Telegram webhook received with invalid secret');
        throw new UnauthorizedException('Invalid webhook secret');
      }
    }

    // In production webhook mode, node-telegram-bot-api processes the update
    // when we call processUpdate(). In polling mode this endpoint is unused.
    this.logger.debug('Telegram webhook update received');
    return { ok: true };
  }

  // ---------------------------------------------------------------------------
  // Generate a link token (authenticated — member must be logged in to app)
  // ---------------------------------------------------------------------------
  @Post('link-token')
  @ApiOperation({ summary: 'Generate a one-time Telegram link token' })
  async generateLinkToken(
    @CurrentUser() user: { id: string },
  ): Promise<{ token: string; instructions: string }> {
    return this.linkService.generateLinkToken(user.id);
  }

  // ---------------------------------------------------------------------------
  // Unlink Telegram from the current user's account
  // ---------------------------------------------------------------------------
  @Post('unlink')
  @ApiOperation({ summary: 'Unlink Telegram from account' })
  async unlinkTelegram(@CurrentUser() user: { id: string }): Promise<{ ok: boolean }> {
    await this.linkService.unlinkTelegram(user.id);
    return { ok: true };
  }

  // ---------------------------------------------------------------------------
  // Check Telegram link status
  // ---------------------------------------------------------------------------
  @Get('status')
  @ApiOperation({ summary: 'Check if Telegram is linked for current user' })
  async getLinkStatus(
    @CurrentUser() user: { id: string; telegramChatId?: bigint | null },
  ): Promise<{ linked: boolean; linkedAt?: Date | null }> {
    return {
      linked: !!user.telegramChatId,
    };
  }
}
