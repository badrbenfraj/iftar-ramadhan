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
import {
  CreateFastingInput,
  UpdateFastingInput,
} from '../dtos/fasting-input.dto';
import { FastingOutput } from '../dtos/fasting-output.dto';
import { FastingService } from '../services/fasting.service';

@ApiTags('fastings')
@Controller('fastings')
export class FastingController {
  constructor(
    private readonly fastingService: FastingService,
    private readonly logger: AppLogger,
  ) {
    this.logger.setContext(FastingController.name);
  }

  @Post()
  @ApiOperation({
    summary: 'Create fasting API',
  })
  @ApiResponse({
    status: HttpStatus.CREATED,
    type: SwaggerBaseApiResponse(FastingOutput),
  })
  @UseInterceptors(ClassSerializerInterceptor)
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  async createFasting(
    @ReqContext() ctx: RequestContext,
    @Body() input: CreateFastingInput,
  ): Promise<BaseApiResponse<FastingOutput>> {
    const fasting = await this.fastingService.createFasting(ctx, input);
    return { data: fasting, meta: {} };
  }

  @Get()
  @ApiOperation({
    summary: 'Get fastings as a list API',
  })
  @ApiResponse({
    status: HttpStatus.OK,
    type: SwaggerBaseApiResponse([FastingOutput]),
  })
  @UseInterceptors(ClassSerializerInterceptor)
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  async getFastings(
    @ReqContext() ctx: RequestContext,
    @Query() query: PaginationParamsDto,
  ): Promise<BaseApiResponse<FastingOutput[]>> {
    this.logger.log(ctx, `${this.getFastings.name} was called`);

    const { fastings, count } = await this.fastingService.getFastings(
      ctx,
      query.limit,
      query.offset,
    );

    return { data: fastings, meta: { count } };
  }

  @Get(':id')
  @ApiOperation({
    summary: 'Get fasting by id API',
  })
  @ApiResponse({
    status: HttpStatus.OK,
    type: SwaggerBaseApiResponse(FastingOutput),
  })
  @ApiResponse({
    status: HttpStatus.NOT_FOUND,
    type: BaseApiErrorResponse,
  })
  @UseInterceptors(ClassSerializerInterceptor)
  @UseGuards(JwtAuthGuard)
  async getFasting(
    @ReqContext() ctx: RequestContext,
    @Param('id') id: number,
  ): Promise<BaseApiResponse<FastingOutput>> {
    this.logger.log(ctx, `${this.getFasting.name} was called`);

    const fasting = await this.fastingService.getFastingById(ctx, id);
    return { data: fasting, meta: {} };
  }

  @Patch(':id')
  @ApiOperation({
    summary: 'Update fasting API',
  })
  @ApiResponse({
    status: HttpStatus.OK,
    type: SwaggerBaseApiResponse(FastingOutput),
  })
  @UseInterceptors(ClassSerializerInterceptor)
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  async updateFasting(
    @ReqContext() ctx: RequestContext,
    @Param('id') fastingId: number,
    @Body() input: UpdateFastingInput,
  ): Promise<BaseApiResponse<FastingOutput>> {
    const fasting = await this.fastingService.updateFasting(
      ctx,
      fastingId,
      input,
    );
    return { data: fasting, meta: {} };
  }

  @Delete(':id')
  @ApiOperation({
    summary: 'Delete fasting by id API',
  })
  @ApiResponse({
    status: HttpStatus.NO_CONTENT,
  })
  @UseInterceptors(ClassSerializerInterceptor)
  @UseGuards(JwtAuthGuard)
  async deleteFasting(
    @ReqContext() ctx: RequestContext,
    @Param('id') id: number,
  ): Promise<void> {
    this.logger.log(ctx, `${this.deleteFasting.name} was called`);

    return this.fastingService.deleteFasting(ctx, id);
  }
}