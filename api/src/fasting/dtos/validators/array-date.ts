import {
  ValidatorConstraint,
  ValidatorConstraintInterface,
  ValidationArguments,
} from 'class-validator';

@ValidatorConstraint({ name: 'validateDateArray', async: false })
export class ValidateDateArray implements ValidatorConstraintInterface {
  validate(values: any[], args: ValidationArguments) {
    if (!Array.isArray(values)) {
      return false;
    }

    for (const value of values) {
      if (!(value instanceof Date && !isNaN(value.getTime()))) {
        return false;
      }
    }

    return true;
  }

  defaultMessage(args: ValidationArguments) {
    return `${args.property} must be an array of valid Date objects.`;
  }
}
