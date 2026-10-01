import {
  Body,
  ClassSerializerInterceptor,
  Controller,
  Delete,
  Get,
  HttpStatus,
  Param,
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

import { JwtAuthGuard } from '../../auth/guards/jwt-auth.guard';
import {
  BaseApiErrorResponse,
  BaseApiResponse,
  SwaggerBaseApiResponse,
} from '../../shared/dtos/base-api-response.dto';
import { PaginationParamsDto } from '../../shared/dtos/pagination-params.dto';
import { AppLogger } from '../../shared/logger/logger.service';
import { ReqContext } from '../../shared/request-context/req-context.decorator';
import { RequestContext } from '../../shared/request-context/request-context.dto';
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
  @UseGuards(JwtAuthGuard)
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
    type: SwaggerBaseApiResponse([RegionOutput]),
  })
  @UseInterceptors(ClassSerializerInterceptor)
  @ApiBearerAuth()
  async getRegions(
    @ReqContext() ctx: RequestContext,
    @Query() query: PaginationParamsDto,
  ): Promise<BaseApiResponse<RegionOutput[]>> {
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
    @Param('id') id: number,
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
  @UseGuards(JwtAuthGuard)
  async updateRegion(
    @ReqContext() ctx: RequestContext,
    @Param('id') id: number,
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
  @UseGuards(JwtAuthGuard)
  async deleteRegion(
    @ReqContext() ctx: RequestContext,
    @Param('id') id: number,
  ): Promise<void> {
    this.logger.log(ctx, `${this.deleteRegion.name} was called`);

    return this.regionService.deleteRegion(ctx, id);
  }
}
