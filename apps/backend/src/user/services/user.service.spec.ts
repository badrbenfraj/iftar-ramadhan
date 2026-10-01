import { NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import * as bcrypt from 'bcrypt';

import { ROLE } from '../../auth/constants/role.constant';
import { Region } from '../../region/entities/region.entity';
import { AppLogger } from '../../shared/logger/logger.service';
import { RequestContext } from '../../shared/request-context/request-context.dto';
import { CreateUserInput } from '../dtos/user-create-input.dto';
import { UpdateUserInput } from '../dtos/user-update-input.dto';
import { User } from '../entities/user.entity';
import { UserRepository } from '../repositories/user.repository';
import { UserService } from './user.service';

jest.mock('bcrypt', () => ({ hash: jest.fn(), compare: jest.fn() }));

describe('UserService', () => {
  let service: UserService;

  const mockedRepository = {
    save: jest.fn(),
    findOne: jest.fn(),
    findAndCount: jest.fn(),
    getById: jest.fn(),
  };

  const region: Region = {
    id: 0,
    name: '',
    active: false,
    fastingPeople: [],
    users: [],
    createdAt: new Date(),
    updatedAt: new Date(),
    createdBy: new User(),
  };

  const user = {
    id: 6,
    region,
    username: 'jhon',
    name: 'Jhon doe',
    roles: [ROLE.USER],
  };

  const mockedLogger = { setContext: jest.fn(), log: jest.fn() };

  beforeEach(async () => {
    const moduleRef: TestingModule = await Test.createTestingModule({
      providers: [
        UserService,
        {
          provide: UserRepository,
          useValue: mockedRepository,
        },
        { provide: AppLogger, useValue: mockedLogger },
      ],
    }).compile();

    service = moduleRef.get<UserService>(UserService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  const ctx = new RequestContext();

  describe('createUser', () => {
    beforeEach(() => {
      (bcrypt.hash as unknown as jest.Mock).mockImplementation(
        async () => 'hashed-password',
      );

      jest
        .spyOn(mockedRepository, 'save')
        .mockImplementation(async (input) => ({ id: 6, ...input }));
    });

    it('should encrypt password before saving', async () => {
      const userInput = {
        name: user.name,
        region: user.region,
        username: user.username,
        password: 'plain-password',
        roles: [ROLE.USER],
        isAccountDisabled: false,
        email: 'randomUser@random.com',
      };

      await service.createUser(ctx, userInput);
      expect(bcrypt.hash).toHaveBeenCalledWith(userInput.password, 10);
    });

    it('should save user with encrypted password', async () => {
      const userInput = {
        name: user.name,
        region: user.region,
        username: user.username,
        password: 'plain-password',
        roles: [ROLE.USER],
        isAccountDisabled: false,
        email: 'randomUser@random.com',
      };

      await service.createUser(ctx, userInput);

      expect(mockedRepository.save).toHaveBeenCalledWith(
        expect.objectContaining({
          name: user.name,
          username: user.username,
          password: 'hashed-password',
          roles: [ROLE.USER],
          isAccountDisabled: false,
          email: 'randomUser@random.com',
        }),
      );
    });

    it('should return serialized user', async () => {
      jest.spyOn(mockedRepository, 'save').mockImplementation(async (input) => {
        input.id = 6;
        return input;
      });

      const userInput: CreateUserInput = {
        name: user.name,
        username: user.username,
        password: 'plain-password',
        roles: [ROLE.USER],
        isAccountDisabled: false,
        email: 'randomUser@random.com',
        region: user.region,
      };

      const result = await service.createUser(ctx, userInput);

      expect(result).toEqual(
        expect.objectContaining({
          id: user.id,
          name: userInput.name,
          username: userInput.username,
          roles: [ROLE.USER],
          isAccountDisabled: false,
          email: 'randomUser@random.com',
        }),
      );
      expect(result).not.toHaveProperty('password');
    });

    afterEach(() => {
      jest.resetAllMocks();
    });
  });

  describe('findById', () => {
    beforeEach(() => {
      jest
        .spyOn(mockedRepository, 'findOne')
        .mockImplementation(async () => user);
    });

    it('should find user from DB using given id', async () => {
      await service.findById(ctx, user.id);
      expect(mockedRepository.findOne).toHaveBeenCalledWith({
        where: { id: user.id },
        relations: { region: true },
      });
    });

    it('should return serialized user', async () => {
      const result = await service.findById(ctx, user.id);

      expect(result).toEqual(
        expect.objectContaining({
          id: user.id,
          name: user.name,
          username: user.username,
          roles: [ROLE.USER],
        }),
      );
    });

    afterEach(() => {
      jest.resetAllMocks();
    });
  });

  describe('getUserById', () => {
    beforeEach(() => {
      jest
        .spyOn(mockedRepository, 'getById')
        .mockImplementation(async () => user);
    });

    it('should find user from DB using given id', async () => {
      await service.getUserById(ctx, user.id);
      expect(mockedRepository.getById).toHaveBeenCalledWith(user.id);
    });

    it('should return serialized user', async () => {
      const result = await service.getUserById(ctx, user.id);

      expect(result).toEqual(
        expect.objectContaining({
          id: user.id,
          name: user.name,
          username: user.username,
          roles: [ROLE.USER],
        }),
      );
    });

    it('throw not found exception if user is not found', async () => {
      mockedRepository.findOne.mockResolvedValue(null);
      try {
        await service.getUserById(ctx, 100);
      } catch (error) {
        expect(error.constructor).toBe(NotFoundException);
      }
    });

    afterEach(() => {
      jest.resetAllMocks();
    });
  });

  describe('validateUsernamePassword', () => {
    it('should fail when username is invalid', async () => {
      jest
        .spyOn(mockedRepository, 'findOne')
        .mockImplementation(async () => null);

      await expect(
        service.validateUsernamePassword(ctx, 'jhon', 'password'),
      ).rejects.toThrow();
    });

    it('should fail when password is invalid', async () => {
      jest
        .spyOn(mockedRepository, 'findOne')
        .mockImplementation(async () => user);

      (bcrypt.compare as unknown as jest.Mock).mockImplementation(
        async () => false,
      );

      await expect(
        service.validateUsernamePassword(ctx, 'jhon', 'password'),
      ).rejects.toThrow();
    });

    it('should return  user  when credentials are valid', async () => {
      jest
        .spyOn(mockedRepository, 'findOne')
        .mockImplementation(async () => user);

      (bcrypt.compare as unknown as jest.Mock).mockImplementation(
        async () => true,
      );

      const result = await service.validateUsernamePassword(
        ctx,
        'jhon',
        'password',
      );

      expect(result).toEqual(
        expect.objectContaining({
          id: user.id,
          name: user.name,
          username: user.username,
          roles: [ROLE.USER],
        }),
      );
    });
  });

  describe('getUsers', () => {
    it('gets users as a list', async () => {
      const offset = 0;
      const limit = 0;
      mockedRepository.findAndCount.mockResolvedValue([[user], 1]);
      await service.getUsers(ctx, limit, offset);
      expect(mockedRepository.findAndCount).toHaveBeenCalled();
    });
  });

  describe('findByUsername', () => {
    beforeEach(() => {
      jest
        .spyOn(mockedRepository, 'findOne')
        .mockImplementation(async () => user);
    });

    it('should find user from DB using given username', async () => {
      await service.findByUsername(ctx, user.username);
      expect(mockedRepository.findOne).toHaveBeenCalledWith({
        where: {
          username: user.username,
        },
      });
    });

    it('should return serialized user', async () => {
      const result = await service.findByUsername(ctx, user.username);

      expect(result).toEqual(
        expect.objectContaining({
          id: user.id,
          name: user.name,
          username: user.username,
          roles: [ROLE.USER],
        }),
      );
    });

    afterEach(() => {
      jest.resetAllMocks();
    });
  });

  describe('updateUser', () => {
    it('should call repository.save with correct input', async () => {
      const userId = 1;
      const input: UpdateUserInput = {
        name: 'Test',
        password: 'updated-password',
      };

      const currentDate = new Date();

      const foundUser: User = {
        id: userId,
        name: 'Default User',
        username: 'default-user',
        password: 'random-password',
        roles: [ROLE.USER],
        isAccountDisabled: false,
        email: 'randomUser@random.com',
        createdAt: currentDate,
        updatedAt: currentDate,
        fastings: [],
        region: user.region,
      };

      mockedRepository.findOne.mockResolvedValue(foundUser);

      const expected: User = {
        ...foundUser,
        name: input.name,
        username: 'default-user',
        password: input.password,
        roles: [ROLE.USER],
        isAccountDisabled: false,
        email: 'randomUser@random.com',
        createdAt: currentDate,
        updatedAt: currentDate,
        fastings: [],
        region: user.region,
      };

      (bcrypt.hash as unknown as jest.Mock).mockImplementation(
        async () => 'updated-password',
      );

      await service.updateUser(ctx, userId, input);
      expect(mockedRepository.save).toHaveBeenCalledWith(expected);
    });

    it('should throw not found exception if user not found', async () => {
      const userId = 1;
      const input: UpdateUserInput = {
        name: 'Test',
        password: 'updated-password',
      };

      mockedRepository.findOne.mockResolvedValue(null);

      try {
        await service.updateUser(ctx, userId, input);
      } catch (error) {
        expect(error).toBeInstanceOf(NotFoundException);
      }
    });
  });
});
