import {
  Body,
  ClassSerializerInterceptor,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
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
  ConfirmMealInput,
  CreateFastingInput,
  UpdateFastingInput,
} from '../dtos/fasting-input.dto';
import { FastingOutput } from '../dtos/fasting-output.dto';
import { DailyStatistics, FastingService } from '../services/fasting.service';

@ApiTags('fastings')
@Controller('fastings')
export class FastingController {
  constructor(
    private readonly fastingService: FastingService,
    private readonly logger: AppLogger,
  ) {
    this.logger.setContext(FastingController.name);
  }

  // Put most specific routes first
  @Get('statistics/:region')
  @ApiOperation({
    summary: 'Get statistics fastings by region API',
  })
  @ApiResponse({
    status: HttpStatus.OK,
    type: SwaggerBaseApiResponse([FastingOutput]),
  })
  @UseInterceptors(ClassSerializerInterceptor)
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  async getFastingsStatisticsByRegion(
    @ReqContext() ctx: RequestContext,
    @Param('region') region: number,
    @Query('start') start: string,
    @Query('end') end: string,
  ): Promise<BaseApiResponse<DailyStatistics[]>> {
    this.logger.log(
      ctx,
      `${this.getFastingsStatisticsByRegion.name} was called`,
    );

    const statistics = await this.fastingService.getStatistics(
      ctx,
      region,
      start,
      end,
    );

    return { data: statistics, meta: {} };
  }

  @Get(':region/:id')
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
    @Param('region') region: number,
    @Param('id') id: number,
  ): Promise<BaseApiResponse<FastingOutput>> {
    this.logger.log(ctx, `${this.getFasting.name} was called`);

    const fasting = await this.fastingService.getFastingById(ctx, id, region);
    return { data: fasting, meta: {} };
  }

  @Patch(':region/:id')
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
    @Param('region') region: number,
    @Param('id') fastingId: number,
    @Body() input: UpdateFastingInput,
  ): Promise<BaseApiResponse<FastingOutput>> {
    const fasting = await this.fastingService.updateFasting(
      ctx,
      fastingId,
      region,
      input,
    );
    return { data: fasting, meta: {} };
  }

  @Patch('confirm/:region/:id')
  @ApiOperation({
    summary: 'confirm meal taken fasting API',
  })
  @ApiResponse({
    status: HttpStatus.OK,
    type: SwaggerBaseApiResponse(FastingOutput),
  })
  @ApiResponse({
    status: HttpStatus.CONFLICT,
    description:
      'Meal already collected today (details.code = MEAL_ALREADY_TAKEN)',
    type: BaseApiErrorResponse,
  })
  @ApiResponse({
    status: HttpStatus.NOT_FOUND,
    type: BaseApiErrorResponse,
  })
  @UseInterceptors(ClassSerializerInterceptor)
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  async confirmFastingMeal(
    @ReqContext() ctx: RequestContext,
    @Param('region') region: number,
    @Param('id') fastingId: number,
    @Body() input: ConfirmMealInput,
  ): Promise<BaseApiResponse<FastingOutput>> {
    this.logger.log(ctx, `${this.confirmFastingMeal.name} was called`);

    const fasting = await this.fastingService.confirmMeal(
      ctx,
      fastingId,
      region,
      input,
    );
    return { data: fasting, meta: {} };
  }

  @Post('meals/:eventId/revoke')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Undo a meal confirmation (spec 2A §4.2)',
  })
  @ApiResponse({
    status: HttpStatus.OK,
    type: SwaggerBaseApiResponse(FastingOutput),
  })
  @ApiResponse({
    status: HttpStatus.FORBIDDEN,
    description:
      "details.code = UNDO_NOT_ALLOWED (someone else's meal) or UNDO_WINDOW_EXPIRED",
    type: BaseApiErrorResponse,
  })
  @ApiResponse({
    status: HttpStatus.NOT_FOUND,
    description: 'details.code = MEAL_EVENT_NOT_FOUND',
    type: BaseApiErrorResponse,
  })
  @UseInterceptors(ClassSerializerInterceptor)
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  async revokeMeal(
    @ReqContext() ctx: RequestContext,
    @Param('eventId', new ParseUUIDPipe()) eventId: string,
  ): Promise<BaseApiResponse<FastingOutput>> {
    this.logger.log(ctx, `${this.revokeMeal.name} was called`);

    const fasting = await this.fastingService.revokeMeal(ctx, eventId);
    return { data: fasting, meta: {} };
  }

  @Delete(':region/:id')
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
    @Param('region') region: number,
    @Param('id') id: number,
  ): Promise<void> {
    this.logger.log(ctx, `${this.deleteFasting.name} was called`);

    return this.fastingService.deleteFasting(ctx, id, region);
  }

  @Get(':region')
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
  async getFastingsByRegion(
    @ReqContext() ctx: RequestContext,
    @Param('region') region: number,
    @Query() query: PaginationParamsDto,
  ): Promise<BaseApiResponse<FastingOutput[]>> {
    this.logger.log(ctx, `${this.getFastingsByRegion.name} was called`);

    const { fastings, count } = await this.fastingService.getFastingsByRegion(
      ctx,
      region,
      query.limit,
      query.offset,
    );

    return { data: fastings, meta: { count } };
  }

  // Put most generic routes last
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
    // A person who did not come today starts with an empty history: they are
    // eligible today without a fake meal being recorded for them.
    if (input.cameToday === true) {
      const today = new Date();
      input.lastTakenMeal = today;
      input.takenMeals = [today];
    } else {
      input.lastTakenMeal = null;
      input.takenMeals = [];
    }

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
}
