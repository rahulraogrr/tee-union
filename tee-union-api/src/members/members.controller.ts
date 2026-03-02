import { Controller, Get, Param, Query, Patch, Body, ParseUUIDPipe } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation, ApiQuery } from '@nestjs/swagger';
import { UserRole } from '@prisma/client';
import { MembersService } from './members.service';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';

@ApiTags('Members')
@ApiBearerAuth()
@Controller('members')
export class MembersController {
  constructor(private membersService: MembersService) {}

  @Get('me')
  @ApiOperation({ summary: 'Get my own member profile' })
  getMyProfile(@CurrentUser('id') userId: string) {
    return this.membersService.getMyProfile(userId);
  }

  @Patch('me')
  @ApiOperation({ summary: 'Update my address, mobile, marital status' })
  updateMyProfile(
    @CurrentUser('id') userId: string,
    @Body() body: any,
  ) {
    return this.membersService.updateMyProfile(userId, body);
  }

  @Get()
  @Roles(UserRole.super_admin, UserRole.admin, UserRole.zonal_officer, UserRole.rep)
  @ApiOperation({ summary: 'List all members (admin / rep only)' })
  @ApiQuery({ name: 'districtId', required: false })
  @ApiQuery({ name: 'employerId', required: false })
  @ApiQuery({ name: 'designationId', required: false })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  findAll(@Query() query: any) {
    return this.membersService.findAll({
      districtId: query.districtId,
      employerId: query.employerId,
      designationId: query.designationId,
      isActive: query.isActive !== undefined ? query.isActive === 'true' : undefined,
      page: query.page ? +query.page : 1,
      limit: query.limit ? +query.limit : 20,
    });
  }

  @Get(':id')
  @Roles(UserRole.super_admin, UserRole.admin, UserRole.zonal_officer, UserRole.rep)
  @ApiOperation({ summary: 'Get a single member by ID (admin / rep only)' })
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.membersService.findOne(id);
  }
}
