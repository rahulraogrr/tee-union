"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AppModule = void 0;
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const core_1 = require("@nestjs/core");
const bull_1 = require("@nestjs/bull");
const http_logger_middleware_1 = require("./common/middleware/http-logger.middleware");
const prisma_module_1 = require("./prisma/prisma.module");
const auth_module_1 = require("./auth/auth.module");
const members_module_1 = require("./members/members.module");
const tickets_module_1 = require("./tickets/tickets.module");
const news_module_1 = require("./news/news.module");
const events_module_1 = require("./events/events.module");
const notifications_module_1 = require("./notifications/notifications.module");
const jwt_auth_guard_1 = require("./common/guards/jwt-auth.guard");
const roles_guard_1 = require("./common/guards/roles.guard");
const all_exceptions_filter_1 = require("./common/filters/all-exceptions.filter");
let AppModule = class AppModule {
    configure(consumer) {
        consumer.apply(http_logger_middleware_1.HttpLoggerMiddleware).forRoutes('*');
    }
};
exports.AppModule = AppModule;
exports.AppModule = AppModule = __decorate([
    (0, common_1.Module)({
        imports: [
            config_1.ConfigModule.forRoot({ isGlobal: true }),
            bull_1.BullModule.forRootAsync({
                imports: [config_1.ConfigModule],
                useFactory: (config) => ({
                    redis: {
                        host: config.get('REDIS_HOST') ?? 'localhost',
                        port: config.get('REDIS_PORT') ?? 6379,
                        password: config.get('REDIS_PASSWORD') || undefined,
                        enableReadyCheck: false,
                        maxRetriesPerRequest: null,
                        lazyConnect: true,
                    },
                }),
                inject: [config_1.ConfigService],
            }),
            prisma_module_1.PrismaModule,
            auth_module_1.AuthModule,
            members_module_1.MembersModule,
            tickets_module_1.TicketsModule,
            news_module_1.NewsModule,
            events_module_1.EventsModule,
            notifications_module_1.NotificationsModule,
        ],
        providers: [
            { provide: core_1.APP_GUARD, useClass: jwt_auth_guard_1.JwtAuthGuard },
            { provide: core_1.APP_GUARD, useClass: roles_guard_1.RolesGuard },
            { provide: core_1.APP_FILTER, useClass: all_exceptions_filter_1.AllExceptionsFilter },
        ],
    })
], AppModule);
//# sourceMappingURL=app.module.js.map