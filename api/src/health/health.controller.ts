import { Controller, Get } from "@nestjs/common";
import { ApiOperation,ApiTags } from "@nestjs/swagger";
import { 
  DiskHealthIndicator,
  HealthCheck, 
  HealthCheckService, 
  MemoryHealthIndicator 
} from "@nestjs/terminus";

import { DatabaseHealthIndicator } from "./database.health";

@ApiTags("Health")
@Controller("health")
export class HealthController {
  constructor(
    private readonly health: HealthCheckService,
    private readonly database: DatabaseHealthIndicator,
    private readonly disk: DiskHealthIndicator,
    private readonly memory: MemoryHealthIndicator,
  ) {}

  @Get()
  @HealthCheck()
  @ApiOperation({ summary: 'Check system health' })
  check() {
    return this.health.check([
      // Database health
      () => this.database.isHealthy(),
      
      // Memory heap check
      () => this.memory.checkHeap('memory_heap', 150 * 1024 * 1024), // 150MB
      
      // Disk storage check
      () => this.disk.checkStorage('disk_health', {
        thresholdPercent: 0.9,
        path: '/',
      }),
      
      // External API checks if needed
      // () => this.http.pingCheck('external_api', 'https://api.example.com'),
    ]);
  }
}
