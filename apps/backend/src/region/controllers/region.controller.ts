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
  Query,
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
import { PaginationParamsDto } from '../../shared/dtos/pagination-params.dto';
import { AppLogger } from '../../shared/logger/logger.service';
import { ReqContext } from '../../shared/request-context/req-context.decorator';
import { RequestContext } from '../../shared/request-context/request-context.dto';
import { JoinCodeOutput } from '../dtos/join-code-output.dto';
import { PublicRegionOutput } from '../dtos/public-region-output.dto';
import { CreateRegionInput, UpdateRegionInput } from '../dtos/region-input.dto';
import { RegionOutput } from '../dtos/region-output.dto';
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

  @Get()
  @ApiOperation({
    summary: 'Get regions as a list API',
  })
  @ApiResponse({
    status: HttpStatus.OK,
    type: SwaggerBaseApiResponse([PublicRegionOutput]),
  })
  @UseInterceptors(ClassSerializerInterceptor)
  @ApiBearerAuth()
  async getRegions(
    @ReqContext() ctx: RequestContext,
    @Query() query: PaginationParamsDto,
  ): Promise<BaseApiResponse<PublicRegionOutput[]>> {
    this.logger.log(ctx, `${this.getRegions.name} was called`);

    const { regions, count } = await this.regionService.getRegions(
      ctx,
      query.limit,
      query.offset,
    );

    return { data: regions, meta: { count } };
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
    summary: 'Delete region by id API',
  })
  @ApiResponse({
    status: HttpStatus.NO_CONTENT,
  })
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
}
