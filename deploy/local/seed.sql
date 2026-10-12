-- DEV ONLY. Never run against production: it creates accounts with a
-- known password. deploy/deploy-backend.sh does not ship deploy/local/.
-- Local dev data, run by the `seed` service in compose.yml after the API's
-- migrations and CLI setup (admin + regions Dar Sokra / Dar Sousse).
-- Idempotent: existing rows are left alone, so it runs on every `up`.
-- Every seeded account's password is: test-pass
--
-- People start with no meals: meal history lives in meal_events and must stay
-- in step with fastings.takenMeals, so serve meals through the app instead.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Join codes, so registration with a code can be tried right away.
UPDATE regions SET "joinCode" = 'NOUR-111111'  WHERE name = 'Dar Sokra'  AND "joinCode" IS NULL;
UPDATE regions SET "joinCode" = 'RAHMA-222222' WHERE name = 'Dar Sousse' AND "joinCode" IS NULL;

-- One account per role / status.
INSERT INTO users (name, username, email, password, roles, status, "regionId", "regionName", "joinedWithCode")
SELECT u.name, u.username, u.username || '@example.test',
       crypt('test-pass', gen_salt('bf', 10)), u.roles, u.status, r.id, r.name, u.joined
FROM (VALUES
  ('Coordinatrice Sokra', 'coord',   'REGION_ADMIN', 'active',  'Dar Sokra',  true),
  ('Bénévole Sokra',      'vol1',    'USER',         'active',  'Dar Sokra',  true),
  ('Bénévole en attente', 'pending', 'USER',         'pending', 'Dar Sokra',  false),
  ('Bénévole désactivé',  'off',     'USER',         'disabled','Dar Sokra',  true),
  ('Bénévole Sousse',     'vol2',    'USER',         'active',  'Dar Sousse', true)
) AS u(name, username, roles, status, region, joined)
JOIN regions r ON r.name = u.region
ON CONFLICT (username) DO NOTHING;

-- Fasting people: cards 1-40 in Dar Sokra and 1-15 in Dar Sousse. Every
-- region prints the same card numbers, so the two lists overlap on purpose.
-- k only varies the fake details between the two regions.
WITH first_names(v, n) AS (
  SELECT * FROM unnest(ARRAY['محمد','فاطمة','أحمد','عائشة','علي','مريم','يوسف','خديجة','عمر','سارة',
                             'Mohamed','Fatma','Ahmed','Amira','Karim','Nour','Hichem','Salma'])
                WITH ORDINALITY AS t(v, n)
), last_names(v, n) AS (
  SELECT * FROM unnest(ARRAY['الطرابلسي','بن علي','الجندوبي','الرميلي','الحمامي','السوسي',
                             'Ben Salah','Trabelsi','Gharbi','Jaziri','Mejri','Bouazizi'])
                WITH ORDINALITY AS t(v, n)
), people AS (
  SELECT id, id AS k, 'Dar Sokra' AS region FROM generate_series(1, 40) AS s(id)
  UNION ALL
  SELECT id, id + 100 AS k, 'Dar Sousse' FROM generate_series(1, 15) AS s(id)
)
INSERT INTO fastings (id, "firstName", "lastName", phone, comment, "familyMeal", "singleMeal",
                      cin, "regionId", "regionName", "createdById")
SELECT p.id,
       (SELECT v FROM first_names WHERE n = 1 + p.k % 18),
       (SELECT v FROM last_names  WHERE n = 1 + (p.k * 7) % 12),
       CASE WHEN p.k % 3 = 0 THEN NULL ELSE '2' || lpad((p.k * 7919 % 10000000)::text, 7, '0') END,
       CASE WHEN p.k % 9 = 0 THEN 'يسكن قرب الجامع' WHEN p.k % 11 = 0 THEN 'Needs a vegetarian meal' END,
       CASE WHEN p.k % 4 = 0 THEN 0 ELSE 1 + p.k % 3 END,
       CASE WHEN p.k % 4 = 0 THEN 1 ELSE p.k % 2 END,
       CASE WHEN p.k % 5 = 0 THEN NULL ELSE lpad((p.k * 104729 % 100000000)::text, 8, '0') END,
       r.id, r.name, (SELECT id FROM users WHERE username = 'admin')
FROM people p
JOIN regions r ON r.name = p.region
ON CONFLICT ("regionId", id) DO NOTHING;
