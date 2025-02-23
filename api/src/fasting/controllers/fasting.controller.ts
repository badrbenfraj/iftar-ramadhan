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
  ): Promise<BaseApiResponse<any>> {
    this.logger.log(ctx, `${this.getFastingsByRegion.name} was called`);

    const { fastings, count } = await this.fastingService.getFastingsByRegion(
      ctx,
      region,
      Number.MAX_SAFE_INTEGER,
      0,
    );

    const startDate = new Date(start);
    const endDate = new Date(end);

    const statisticsByDay = {};

    // Iterate over the range of dates and initialize statistics for each day
    for (
      let currentDate = new Date(startDate);
      currentDate <= endDate;
      currentDate.setDate(currentDate.getDate() + 1)
    ) {
      statisticsByDay[currentDate.toDateString()] = {
        totalPersons: 0,
        persons: 0,
        singleMeal: 0,
        familyMeal: 0,
        totalMeals: 0,
      };
    }

    // Iterate over the fasting data and update statistics for each day
    fastings.forEach((person) => {
      person.takenMeals.forEach((takenMealDate) => {
        const mealDate = new Date(takenMealDate).getTime();
        if (mealDate >= startDate.getTime() && mealDate <= endDate.getTime()) {
          const date = new Date(mealDate).toDateString();
          const statistics = statisticsByDay[date];
          if (statistics) {
            statistics.totalPersons = count;
            statistics.persons += 1;
            statistics.singleMeal += person?.singleMeal || 0;
            statistics.familyMeal += person?.familyMeal * 4 || 0;
            statistics.totalMeals +=
              (person?.singleMeal || 0) + (person?.familyMeal * 4 || 0);
          }
        }
      });
    });

    // Convert statisticsByDay object to array format
    const statisticsArray = Object.entries(statisticsByDay).map(
      ([date, statistics]) => ({
        date,
        statistics,
      }),
    );

    return {
      data: statisticsArray,
      meta: {},
    };
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
    const today = new Date();
    if (input.cameToday === true) {
      input.lastTakenMeal = today;
      input.takenMeals = [today];
    } else {
      today.setDate(today.getDate() - 1);
      input.lastTakenMeal = today;
      input.takenMeals = [today];
    }

    const fasting = await this.fastingService.createFasting(ctx, input);
    return { data: fasting, meta: {} };
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
  @UseInterceptors(ClassSerializerInterceptor)
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  async confirmFastingMeal(
    @ReqContext() ctx: RequestContext,
    @Param('region') region: number,
    @Param('id') fastingId: number,
    @Body() input: UpdateFastingInput,
  ): Promise<BaseApiResponse<FastingOutput>> {
    input.lastTakenMeal = new Date();
    const fasting = await this.fastingService.updateFasting(
      ctx,
      fastingId,
      region,
      input,
      true,
    );
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
}
