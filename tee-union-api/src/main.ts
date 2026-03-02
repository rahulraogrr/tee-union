import { NestFactory, Reflector } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  // ── Global prefix ──────────────────────────────────────────────────────────
  app.setGlobalPrefix('api/v1');

  // ── CORS (allow React Native / Expo dev clients) ───────────────────────────
  app.enableCors({
    origin: '*',              // Lock down to your app domain in production
    methods: ['GET', 'POST', 'PATCH', 'DELETE'],
    allowedHeaders: ['Content-Type', 'Authorization'],
  });

  // ── Validation pipe (class-validator) ─────────────────────────────────────
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,          // Strip unknown properties
      forbidNonWhitelisted: true,
      transform: true,          // Auto-transform types (string → number, etc.)
    }),
  );

  // ── Swagger / OpenAPI ──────────────────────────────────────────────────────
  const config = new DocumentBuilder()
    .setTitle('TEE 1104 Union API')
    .setDescription(
      'NestJS + Prisma + PostgreSQL backend for the TEE 1104 Union mobile app.\n\n' +
      '**Authentication:** Employee ID + 4-digit PIN → JWT Bearer token.\n\n' +
      'All endpoints (except `POST /auth/login` and `POST /telegram/webhook`) require ' +
      'a valid `Authorization: Bearer <token>` header.',
    )
    .setVersion('1.0')
    .addBearerAuth(
      { type: 'http', scheme: 'bearer', bearerFormat: 'JWT', in: 'header' },
      'bearer',
    )
    .addTag('Auth',          'Login and PIN management')
    .addTag('Members',       'Member profiles and directory')
    .addTag('Tickets',       'Grievance ticketing system')
    .addTag('News',          'Union news and announcements')
    .addTag('Events',        'Union events and registrations')
    .addTag('Notifications', 'In-app notification inbox')
    .addTag('Telegram',      'Telegram bot account linking')
    .build();

  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api/docs', app, document, {
    swaggerOptions: { persistAuthorization: true },
  });

  // ── Start server ───────────────────────────────────────────────────────────
  const port = process.env.PORT ?? 3000;
  await app.listen(port);
  console.log(`\n🚀  TEE 1104 Union API running on: http://localhost:${port}/api/v1`);
  console.log(`📖  Swagger docs:                  http://localhost:${port}/api/docs\n`);
}

bootstrap();
