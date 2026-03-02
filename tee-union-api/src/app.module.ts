import { MiddlewareConsumer, Module, NestModule } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { APP_GUARD, APP_FILTER } from '@nestjs/core';
import { BullModule } from '@nestjs/bull';

import { HttpLoggerMiddleware } from './common/middleware/http-logger.middleware';

import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './auth/auth.module';
import { MembersModule } from './members/members.module';
import { TicketsModule } from './tickets/tickets.module';
import { NewsModule } from './news/news.module';
import { EventsModule } from './events/events.module';
import { NotificationsModule } from './notifications/notifications.module';

import { JwtAuthGuard } from './common/guards/jwt-auth.guard';
import { RolesGuard } from './common/guards/roles.guard';
import { AllExceptionsFilter } from './common/filters/all-exceptions.filter';

@Module({
  imports: [
    // Config (loads .env)
    ConfigModule.forRoot({ isGlobal: true }),

    // Bull / Redis — used by notification queue
    // enableReadyCheck: false + lazyConnect: true mean the app starts
    // even if Redis is not yet available; queue jobs simply won't process.
    BullModule.forRootAsync({
      imports: [ConfigModule],
      useFactory: (config: ConfigService) => ({
        redis: {
          host: config.get<string>('REDIS_HOST') ?? 'localhost',
          port: config.get<number>('REDIS_PORT') ?? 6379,
          password: config.get<string>('REDIS_PASSWORD') || undefined,
          enableReadyCheck: false,
          maxRetriesPerRequest: null,
          lazyConnect: true,
        },
      }),
      inject: [ConfigService],
    }),

    // Database
    PrismaModule,

    // Feature modules
    AuthModule,
    MembersModule,
    TicketsModule,
    NewsModule,
    EventsModule,

    // Notification system (FCM + Telegram + SMS + BullMQ)
    NotificationsModule,
  ],
  providers: [
    // JWT guard applied globally — use @Public() to opt out
    { provide: APP_GUARD, useClass: JwtAuthGuard },

    // Role guard applied globally — use @Roles(...) to restrict
    { provide: APP_GUARD, useClass: RolesGuard },

    // Global exception filter — consistent error response shape
    { provide: APP_FILTER, useClass: AllExceptionsFilter },
  ],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer.apply(HttpLoggerMiddleware).forRoutes('*');
  }
}
