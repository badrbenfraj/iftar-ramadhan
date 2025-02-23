import { Injectable, NotFoundException } from '@nestjs/common';
import { RegionRepository } from 'src/region/repositories/region.repository';
import { DataSource, Repository } from 'typeorm';

import { Fasting } from '../entities/fasting.entity';

@Injectable()
export class FastingRepository extends Repository<Fasting> {
  constructor(
    private dataSource: DataSource,
    private regionRepository: RegionRepository,
  ) {
    super(Fasting, dataSource.createEntityManager());
  }

  async getFastingsByRegion(
    regionId: number,
    limit: number,
    offset: number,
  ): Promise<[Fasting[], number]> {
    const fasting = await this.findAndCount({
      where: {
        region: { id: regionId },
      },
      relations: ['region'],
      take: limit,
      skip: offset,
    });

    if (!fasting) {
      throw new NotFoundException();
    }

    return fasting;
  }

  async getByIdAndRegion(id: number, regionId: number): Promise<Fasting> {
    if (!id || !regionId) {
      throw new NotFoundException('Fasting ID and Region ID are required');
    }

    const region = await this.regionRepository.getRegionById(regionId);
    if (!region) {
      throw new NotFoundException(`Region with ID ${regionId} not found`);
    }

    const fasting = await this.findOne({
      where: { id, region: { id: regionId } },
      relations: ['region'],
    });
    if (!fasting) {
      throw new NotFoundException(`Fasting record with ID ${id} not found in region ${regionId}`);
    }

    return fasting;
  }
}
