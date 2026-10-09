/** Machine-readable auth/access codes returned in `error.details.code`. */
export const AUTH_ERROR_CODES = {
  ACCOUNT_PENDING: 'ACCOUNT_PENDING',
  ACCOUNT_DISABLED: 'ACCOUNT_DISABLED',
  REGION_FORBIDDEN: 'REGION_FORBIDDEN',
  INVALID_JOIN_CODE: 'INVALID_JOIN_CODE',
  NO_REGION: 'NO_REGION',
} as const;
