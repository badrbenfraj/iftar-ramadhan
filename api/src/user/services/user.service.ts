import {
  ConflictException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { compare, hash } from 'bcrypt';
import { plainToClass } from 'class-transformer';

import { AppLogger } from '../../shared/logger/logger.service';
import { RequestContext } from '../../shared/request-context/request-context.dto';
import { CreateUserInput } from '../dtos/user-create-input.dto';
import { UserOutput } from '../dtos/user-output.dto';
import { User } from '../entities/user.entity';
import { UserRepository } from '../repositories/user.repository';

@Injectable()
export class UserService {
  constructor(
    private repository: UserRepository,
    private readonly logger: AppLogger,
  ) {
    this.logger.setContext(UserService.name);
  }
  async createUser(
    ctx: RequestContext,
    input: CreateUserInput,
  ): Promise<UserOutput> {
    this.logger.log(ctx, `${this.createUser.name} was called`);

    const existingUser = await this.repository.findOne({
      where: [{ username: input.username }, { email: input.email }],
    });

    if (existingUser) {
      throw new ConflictException('Username or email is already in use');
    }

    const user = plainToClass(User, input);

    user.password = await hash(input.password, 10);

    this.logger.log(ctx, `calling ${UserRepository.name}.saveUser`);
    await this.repository.save(user);

    return plainToClass(UserOutput, user);
  }

  async validateUsernamePassword(
    ctx: RequestContext,
    username: string,
    pass: string,
  ): Promise<UserOutput> {
    this.logger.log(ctx, `${this.validateUsernamePassword.name} was called`);

    this.logger.log(ctx, `calling ${UserRepository.name}.findOne`);
    const user = await this.repository.findOne({ where: { username } });
    if (!user) throw new UnauthorizedException();

    const match = await compare(pass, user.password);
    if (!match) throw new UnauthorizedException();

    return plainToClass(UserOutput, user);
  }

  async getUsers(
    ctx: RequestContext,
    limit: number,
    offset: number,
  ): Promise<{ users: UserOutput[]; count: number }> {
    this.logger.log(ctx, `${this.getUsers.name} was called`);

    this.logger.log(ctx, `calling ${UserRepository.name}.findAndCount`);
    const [users, count] = await this.repository.findAndCount({
      where: {},
      take: limit,
      skip: offset,
    });

    const usersOutput = plainToClass(UserOutput, users);

    return { users: usersOutput, count };
  }

  async findById(ctx: RequestContext, id: number): Promise<UserOutput> {
    this.logger.log(ctx, `${this.findById.name} was called`);

    this.logger.log(ctx, `calling ${UserRepository.name}.findOne`);
    const user = await this.repository.findOne({
      where: { id },
      relations: ['region'],
    });

    if (!user) {
      throw new NotFoundException('User not found');
    }

    return plainToClass(UserOutput, user);
  }

  async getUserById(ctx: RequestContext, id: number): Promise<UserOutput> {
    this.logger.log(ctx, `${this.getUserById.name} was called`);

    this.logger.log(ctx, `calling ${UserRepository.name}.getById`);
    const user = await this.repository.getById(id);

    return plainToClass(UserOutput, user);
  }

  async findByUsername(
    ctx: RequestContext,
    username: string,
  ): Promise<UserOutput> {
    this.logger.log(ctx, `${this.findByUsername.name} was called`);

    this.logger.log(ctx, `calling ${UserRepository.name}.findOne`);
    const user = await this.repository.findOne({ where: { username },
      relations: ['region'],
     });

    return plainToClass(UserOutput, user);
  }

  async updateUser(
    ctx: RequestContext,
    userId: number,
    input: Partial<CreateUserInput>,
  ): Promise<UserOutput> {
    this.logger.log(ctx, `${this.updateUser.name} was called`);

    const user = await this.repository.findOne({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('User not found');
    }

    const updated = await this.repository.save({
      ...user,
      ...input,
    });

    return plainToClass(UserOutput, updated);
  }
}
