import { config } from 'dotenv';
import { join } from 'path';
import { DataSource } from 'typeorm';

config();

const appRoot = join(__dirname, '../../');

const dataSource = new DataSource({
  type: 'postgres',
  host: process.env.DB_HOST,
  port: parseInt(process.env.DB_PORT || '5432'),
  username: process.env.DB_USER,
  password: process.env.DB_PASS,
  database: process.env.DB_NAME,
  entities: [join(appRoot, 'src/**/*.entity{.ts,.js}')],
  migrations: [join(appRoot, 'migrations/*{.ts,.js}')],
  synchronize: false,
});

module.exports = dataSource;
