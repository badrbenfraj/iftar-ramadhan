import { Injectable, NotFoundException } from '@nestjs/common';
import { DataSource, Repository } from 'typeorm';

import { Fasting } from '../entities/fasting.entity';
import { Region } from '../enums/regions.enum';

@Injectable()
export class FastingRepository extends Repository<Fasting> {
  constructor(private dataSource: DataSource) {
    super(Fasting, dataSource.createEntityManager());
  }

  async getByIdAndRegion(id: number, region: Region): Promise<Fasting> {
    const fasting = await this.findOne({ where: { id, region } });
    if (!fasting) {
      throw new NotFoundException();
    }

    return fasting;
  }
}
