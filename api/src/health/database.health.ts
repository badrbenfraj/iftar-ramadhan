import { Injectable } from "@nestjs/common";
import { HealthIndicator, HealthIndicatorResult } from "@nestjs/terminus";
import { DataSource } from "typeorm";

@Injectable()
export class DatabaseHealthIndicator extends HealthIndicator {
  constructor(private readonly dataSource: DataSource) {
    super();
  }

  async isHealthy(key: string = 'database'): Promise<HealthIndicatorResult> {
    try {
      if (!this.dataSource.isInitialized) {
        throw new Error('Database connection is not initialized');
      }

      await this.dataSource.query('SELECT 1'); // Simple query to test connection
      
      return this.getStatus(key, true, {
        connection: 'ok',
        uptime: this.dataSource.isInitialized ? 'connected' : 'disconnected'
      });
    } catch (error) {
      return this.getStatus(key, false, {
        message: error.message,
        error: error.name
      });
    }
  }
}
