/** Lifecycle of an account (spec security §3.1). */
export const USER_STATUS = {
  /** Registered without a join code; waits for an admin. */
  PENDING: 'pending',
  ACTIVE: 'active',
  DISABLED: 'disabled',
} as const;

export type UserStatus = (typeof USER_STATUS)[keyof typeof USER_STATUS];
