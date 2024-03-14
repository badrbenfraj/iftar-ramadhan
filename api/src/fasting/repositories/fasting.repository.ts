import { Injectable, NotFoundException } from '@nestjs/common';
import { DataSource, Repository } from 'typeorm';

import { Fasting } from '../entities/fasting.entity';

@Injectable()
export class FastingRepository extends Repository<Fasting> {
  constructor(private dataSource: DataSource) {
    super(Fasting, dataSource.createEntityManager());
  }

  async getById(id: number): Promise<Fasting> {
    const fasting = await this.findOne({ where: { id } });
    if (!fasting) {
      throw new NotFoundException();
    }

    return fasting;
  }
}
