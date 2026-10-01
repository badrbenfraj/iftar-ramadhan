import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iftar_mobile/core/network/app_failure.dart';

DioException _response(int status, Object? body) {
  final options = RequestOptions(path: '/x');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: options, statusCode: status, data: body),
  );
}

void main() {
  group('toAppFailure', () {
    test('maps a 409 MEAL_ALREADY_TAKEN with its timestamp', () {
      final failure = toAppFailure(
        _response(409, {
          'error': {
            'statusCode': 409,
            'message': 'Meal already collected today',
            'details': {
              'code': 'MEAL_ALREADY_TAKEN',
              'lastTakenMeal': '2025-03-03T17:10:00.000Z',
            },
          },
        }),
      );
      expect(failure, isA<MealAlreadyTakenFailure>());
      expect(
        (failure as MealAlreadyTakenFailure).takenAt,
        DateTime.utc(2025, 3, 3, 17, 10).toLocal(),
      );
    });

    test('maps other conflicts with their code', () {
      final failure = toAppFailure(
        _response(409, {
          'error': {
            'message': 'A person with ID 10 already exists',
            'details': {'code': 'PERSON_ID_TAKEN'},
          },
        }),
      );
      expect(failure, isA<ConflictFailure>());
      expect((failure as ConflictFailure).code, 'PERSON_ID_TAKEN');
      expect(failure.message, 'A person with ID 10 already exists');
    });

    test('joins class-validator messages for 400', () {
      final failure = toAppFailure(
        _response(400, {
          'error': {
            'message': 'Bad Request Exception',
            'details': {
              'message': [
                'firstName should not be empty',
                'id must be a number',
              ],
            },
          },
        }),
      );
      expect(failure, isA<ValidationFailure>());
      expect(failure.message, contains('firstName should not be empty'));
    });

    test('maps status codes to failure types', () {
      expect(toAppFailure(_response(401, null)), isA<UnauthorizedFailure>());
      expect(toAppFailure(_response(403, null)), isA<ForbiddenFailure>());
      expect(toAppFailure(_response(404, null)), isA<NotFoundFailure>());
      final server = toAppFailure(_response(502, '<html>'));
      expect(server, isA<ServerFailure>());
      expect(server.isRetryable, isTrue);
    });

    test('maps transport errors to network / timeout failures', () {
      final options = RequestOptions(path: '/x');
      expect(
        toAppFailure(
          DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          ),
        ),
        isA<NetworkFailure>(),
      );
      expect(
        toAppFailure(
          DioException(
            requestOptions: options,
            type: DioExceptionType.receiveTimeout,
          ),
        ),
        isA<TimeoutFailure>(),
      );
    });
  });
}
