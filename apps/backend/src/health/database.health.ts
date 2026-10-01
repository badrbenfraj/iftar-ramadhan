import { Injectable } from '@nestjs/common';
import {
  HealthIndicatorResult,
  HealthIndicatorService,
} from '@nestjs/terminus';
import { DataSource } from 'typeorm';

@Injectable()
export class DatabaseHealthIndicator {
  constructor(
    private readonly dataSource: DataSource,
    private readonly healthIndicatorService: HealthIndicatorService,
  ) {}

  async isHealthy(key: string = 'database'): Promise<HealthIndicatorResult> {
    const indicator = this.healthIndicatorService.check(key);
    try {
      if (!this.dataSource.isInitialized) {
        throw new Error('Database connection is not initialized');
      }

      await this.dataSource.query('SELECT 1'); // Simple query to test connection

      return indicator.up({ connection: 'ok', uptime: 'connected' });
    } catch (error) {
      return indicator.down({ message: error.message, error: error.name });
    }
  }
}
