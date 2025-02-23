import { Injectable, NotFoundException } from '@nestjs/common';
import { DataSource, Repository } from 'typeorm';

import { Region } from '../entities/region.entity';

@Injectable()
export class RegionRepository extends Repository<Region> {
  constructor(private dataSource: DataSource) {
    super(Region, dataSource.createEntityManager());
  }

  async getRegionById(id: number): Promise<Region> {
    const region = await this.findOne({ where: { id } });
    if (!region) {
      throw new NotFoundException();
    }

    return region;
  }
}
