import { randomUUID } from 'crypto';
import { Request, Response } from 'express';

import { REQUEST_ID_TOKEN_HEADER } from '../../constants';

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export const RequestIdMiddleware = (
  req: Request,
  res: Response,
  next: () => void,
): void => {
  /** set request id, if not being set yet */
  if (
    !req.headers[REQUEST_ID_TOKEN_HEADER] ||
    !UUID_PATTERN.test(req.header(REQUEST_ID_TOKEN_HEADER))
  ) {
    req.headers[REQUEST_ID_TOKEN_HEADER] = randomUUID();
  }

  /** set res id in response from req */
  res.set(REQUEST_ID_TOKEN_HEADER, req.headers[REQUEST_ID_TOKEN_HEADER]);
  next();
};
