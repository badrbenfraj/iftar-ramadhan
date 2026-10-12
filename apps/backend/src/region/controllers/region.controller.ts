import {
  Body,
  ClassSerializerInterceptor,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOperation,
  ApiResponse,
  ApiTags,
} from '@nestjs/swagger';

import { ROLE } from '../../auth/constants/role.constant';
import { Roles } from '../../auth/decorators/role.decorator';
import { JwtAuthGuard } from '../../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../../auth/guards/roles.guard';
import {
  BaseApiErrorResponse,
  BaseApiResponse,
  SwaggerBaseApiResponse,
} from '../../shared/dtos/base-api-response.dto';
import { AppLogger } from '../../shared/logger/logger.service';
import { ReqContext } from '../../shared/request-context/req-context.decorator';
import { RequestContext } from '../../shared/request-context/request-context.dto';
import { AdminRegionOutput } from '../dtos/admin-region-output.dto';
import { ApprovalInput } from '../dtos/approval-input.dto';
import { JoinCodeOutput } from '../dtos/join-code-output.dto';
import {
  CloseRegionInput,
  CreateRegionInput,
  UpdateRegionInput,
} from '../dtos/region-input.dto';
import { RegionOutput } from '../dtos/region-output.dto';
import { RegionUsageOutput } from '../dtos/region-usage-output.dto';
import { RegionService } from '../services/region.service';

@ApiTags('regions')
@Controller('regions')
export class RegionController {
  constructor(
    private readonly regionService: RegionService,
    private readonly logger: AppLogger,
  ) {
    this.logger.setContext(RegionController.name);
  }

  @Post()
  @ApiOperation({
    summary: 'Create region API',
  })
  @ApiResponse({
    status: HttpStatus.CREATED,
    type: SwaggerBaseApiResponse(RegionOutput),
  })
  @UseInterceptors(ClassSerializerInterceptor)
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(ROLE.ADMIN)
  async createRegion(
    @ReqContext() ctx: RequestContext,
    @Body() input: CreateRegionInput,
  ): Promise<BaseApiResponse<RegionOutput>> {
    const region = await this.regionService.createRegion(ctx, input);
    return { data: region, meta: {} };
  }

  @Get('all')
  @ApiOperation({ summary: 'Admin: every region, closed ones included' })
  @ApiResponse({
    status: HttpStatus.OK,
    type: SwaggerBaseApiResponse([AdminRegionOutput]),
  })
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(ROLE.ADMIN)
  async getAllRegions(
    @ReqContext() ctx: RequestContext,
  ): Promise<BaseApiResponse<AdminRegionOutput[]>> {
    const regions = await this.regionService.getAllRegions(ctx);
    return { data: regions, meta: { count: regions.length } };
  }

  @Get(':id/usage')
  @ApiOperation({ summary: 'Admin: what still points to a region' })
  @ApiResponse({
    status: HttpStatus.OK,
    type: SwaggerBaseApiResponse(RegionUsageOutput),
  })
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(ROLE.ADMIN)
  async getRegionUsage(
    @ReqContext() ctx: RequestContext,
    @Param('id', ParseIntPipe) id: number,
  ): Promise<BaseApiResponse<RegionUsageOutput>> {
    return { data: await this.regionService.getUsage(ctx, id), meta: {} };
  }

  @Post(':id/close')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Admin: close a region (read-only, its users are blocked)',
  })
  @ApiResponse({
    status: HttpStatus.OK,
    type: SwaggerBaseApiResponse(AdminRegionOutput),
  })
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(ROLE.ADMIN)
  async closeRegion(
    @ReqContext() ctx: RequestContext,
    @Param('id', ParseIntPipe) id: number,
    @Body() input: CloseRegionInput,
  ): Promise<BaseApiResponse<AdminRegionOutput>> {
    return {
      data: await this.regionService.closeRegion(ctx, id, input),
      meta: {},
    };
  }

  @Post(':id/reopen')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Admin: reopen a closed region' })
  @ApiResponse({
    status: HttpStatus.OK,
    type: SwaggerBaseApiResponse(AdminRegionOutput),
  })
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(ROLE.ADMIN)
  async reopenRegion(
    @ReqContext() ctx: RequestContext,
    @Param('id', ParseIntPipe) id: number,
  ): Promise<BaseApiResponse<AdminRegionOutput>> {
    return { data: await this.regionService.reopenRegion(ctx, id), meta: {} };
  }

  @Get(':id')
  @ApiOperation({
    summary: 'Get region by id API',
  })
  @ApiResponse({
    status: HttpStatus.OK,
    type: SwaggerBaseApiResponse(RegionOutput),
  })
  @ApiResponse({
    status: HttpStatus.NOT_FOUND,
    type: BaseApiErrorResponse,
  })
  @UseInterceptors(ClassSerializerInterceptor)
  @UseGuards(JwtAuthGuard)
  async getRegion(
    @ReqContext() ctx: RequestContext,
    @Param('id', ParseIntPipe) id: number,
  ): Promise<BaseApiResponse<RegionOutput>> {
    this.logger.log(ctx, `${this.getRegion.name} was called`);

    const region = await this.regionService.getRegionById(ctx, id);
    return { data: region, meta: {} };
  }

  @Patch(':id')
  @ApiOperation({
    summary: 'Update region API',
  })
  @ApiResponse({
    status: HttpStatus.OK,
    type: SwaggerBaseApiResponse(RegionOutput),
  })
  @UseInterceptors(ClassSerializerInterceptor)
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(ROLE.ADMIN)
  async updateRegion(
    @ReqContext() ctx: RequestContext,
    @Param('id', ParseIntPipe) id: number,
    @Body() input: UpdateRegionInput,
  ): Promise<BaseApiResponse<RegionOutput>> {
    const region = await this.regionService.updateRegion(ctx, id, input);
    return { data: region, meta: {} };
  }

  @Delete(':id')
  @ApiOperation({
    summary: 'Admin: delete an empty region (409 REGION_IN_USE otherwise)',
  })
  @ApiResponse({
    status: HttpStatus.NO_CONTENT,
  })
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiBearerAuth()
  @UseInterceptors(ClassSerializerInterceptor)
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(ROLE.ADMIN)
  async deleteRegion(
    @ReqContext() ctx: RequestContext,
    @Param('id', ParseIntPipe) id: number,
  ): Promise<void> {
    this.logger.log(ctx, `${this.deleteRegion.name} was called`);

    return this.regionService.deleteRegion(ctx, id);
  }

  @Get(':id/join-code')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  async getJoinCode(
    @ReqContext() ctx: RequestContext,
    @Param('id', ParseIntPipe) id: number,
  ): Promise<BaseApiResponse<JoinCodeOutput>> {
    return { data: await this.regionService.getJoinCode(ctx, id), meta: {} };
  }

  @Post(':id/join-code')
  @HttpCode(HttpStatus.OK)
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  async newJoinCode(
    @ReqContext() ctx: RequestContext,
    @Param('id', ParseIntPipe) id: number,
  ): Promise<BaseApiResponse<JoinCodeOutput>> {
    return { data: await this.regionService.newJoinCode(ctx, id), meta: {} };
  }

  @Delete(':id/join-code')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  async turnOffJoinCode(
    @ReqContext() ctx: RequestContext,
    @Param('id', ParseIntPipe) id: number,
  ): Promise<BaseApiResponse<JoinCodeOutput>> {
    return {
      data: await this.regionService.turnOffJoinCode(ctx, id),
      meta: {},
    };
  }

  @Post(':id/approval')
  @HttpCode(HttpStatus.OK)
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  async setApproval(
    @ReqContext() ctx: RequestContext,
    @Param('id', ParseIntPipe) id: number,
    @Body() input: ApprovalInput,
  ): Promise<BaseApiResponse<JoinCodeOutput>> {
    return {
      data: await this.regionService.setApproval(
        ctx,
        id,
        input.approveNewVolunteers,
      ),
      meta: {},
    };
  }
}
