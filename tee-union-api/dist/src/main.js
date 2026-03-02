"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const core_1 = require("@nestjs/core");
const common_1 = require("@nestjs/common");
const swagger_1 = require("@nestjs/swagger");
const app_module_1 = require("./app.module");
async function bootstrap() {
    const app = await core_1.NestFactory.create(app_module_1.AppModule);
    app.setGlobalPrefix('api/v1');
    app.enableCors({
        origin: '*',
        methods: ['GET', 'POST', 'PATCH', 'DELETE'],
        allowedHeaders: ['Content-Type', 'Authorization'],
    });
    app.useGlobalPipes(new common_1.ValidationPipe({
        whitelist: true,
        forbidNonWhitelisted: true,
        transform: true,
    }));
    const config = new swagger_1.DocumentBuilder()
        .setTitle('TEE 1104 Union API')
        .setDescription('NestJS + Prisma + PostgreSQL backend for the TEE 1104 Union mobile app. ' +
        'Authentication: Employee ID + 4-digit PIN → JWT Bearer token.')
        .setVersion('1.0')
        .addBearerAuth()
        .addTag('Auth', 'Login and PIN management')
        .addTag('Members', 'Member profiles and directory')
        .addTag('Tickets', 'Grievance ticketing system')
        .addTag('News', 'Union news and announcements')
        .addTag('Events', 'Union events and registrations')
        .build();
    const document = swagger_1.SwaggerModule.createDocument(app, config);
    swagger_1.SwaggerModule.setup('api/docs', app, document, {
        swaggerOptions: { persistAuthorization: true },
    });
    const port = process.env.PORT ?? 3000;
    await app.listen(port);
    console.log(`\n🚀  TEE 1104 Union API running on: http://localhost:${port}/api/v1`);
    console.log(`📖  Swagger docs:                  http://localhost:${port}/api/docs\n`);
}
bootstrap();
//# sourceMappingURL=main.js.map