import { generateKeyPairSync } from 'crypto';

// Self-contained configuration for e2e runs: ephemeral JWT keys and sane
// defaults, so the suite never depends on (or leaks) real deployment secrets.
// Values already present in the environment win (e.g. DB_HOST in CI/Docker).
const { publicKey, privateKey } = generateKeyPairSync('rsa', {
  modulusLength: 2048,
  publicKeyEncoding: { type: 'spki', format: 'pem' },
  privateKeyEncoding: { type: 'pkcs1', format: 'pem' },
});

const defaults: Record<string, string> = {
  APP_ENV: 'test',
  APP_PORT: '3000',
  APP_TIMEZONE: 'Africa/Tunis',
  DB_HOST: 'localhost',
  DB_PORT: '5432',
  DB_USER: 'root',
  DB_PASS: 'example',
  DB_NAME: 'e2e_test_db',
  JWT_ACCESS_TOKEN_EXP_IN_SEC: '3600',
  JWT_REFRESH_TOKEN_EXP_IN_SEC: '7200',
  DEFAULT_ADMIN_USER_PASSWORD: 'e2e-admin-password',
  JWT_PUBLIC_KEY_BASE64: Buffer.from(publicKey).toString('base64'),
  JWT_PRIVATE_KEY_BASE64: Buffer.from(privateKey).toString('base64'),
};

for (const [key, value] of Object.entries(defaults)) {
  if (!process.env[key]) {
    process.env[key] = value;
  }
}
