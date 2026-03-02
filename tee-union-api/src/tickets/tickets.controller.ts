import {
  Controller, Get, Post, Patch, Body, Param, Query, ParseUUIDPipe, HttpCode, HttpStatus,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation, ApiQuery } from '@nestjs/swagger';
import { TicketStatus, UserRole } from '@prisma/client';
import { TicketsService } from './tickets.service';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';

@ApiTags('Tickets')
@ApiBearerAuth()
@Controller('tickets')
export class TicketsController {
  constructor(private ticketsService: TicketsService) {}

  @Post()
  @Roles(UserRole.member)
  @ApiOperation({ summary: 'Raise a new grievance ticket' })
  create(@CurrentUser('id') userId: string, @Body() body: any) {
    return this.ticketsService.create(userId, body);
  }

  @Get()
  @ApiOperation({ summary: 'List tickets (scoped by caller role)' })
  @ApiQuery({ name: 'status', required: false, enum: TicketStatus })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  findAll(
    @CurrentUser('id') userId: string,
    @CurrentUser('role') role: UserRole,
    @Query() query: any,
  ) {
    return this.ticketsService.findAll(userId, role, {
      status: query.status,
      page: query.page ? +query.page : 1,
      limit: query.limit ? +query.limit : 20,
    });
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get ticket details (members see own only)' })
  findOne(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') userId: string,
    @CurrentUser('role') role: UserRole,
  ) {
    return this.ticketsService.findOne(id, userId, role);
  }

  @Post(':id/comments')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Add a comment to a ticket' })
  addComment(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') userId: string,
    @CurrentUser('role') role: UserRole,
    @Body() body: { comment: string; isInternal?: boolean },
  ) {
    return this.ticketsService.addComment(id, userId, role, body.comment, body.isInternal);
  }

  @Patch(':id/status')
  @Roles(UserRole.super_admin, UserRole.admin, UserRole.zonal_officer, UserRole.rep)
  @ApiOperation({ summary: 'Update ticket status (rep / admin only)' })
  updateStatus(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') userId: string,
    @Body() body: { status: TicketStatus; notes?: string },
  ) {
    return this.ticketsService.updateStatus(id, userId, body.status, body.notes);
  }
}
