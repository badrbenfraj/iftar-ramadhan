# lts-hydrogen refers to v20
# Using this instead of node:16 to avoid dependabot updates
FROM node:lts-hydrogen AS builder

WORKDIR /usr/src/app

COPY package.json package-lock.json ./

RUN npm ci

COPY . .

ARG APP_ENV=development
ENV NODE_ENV=${APP_ENV}

RUN npm run build

RUN npm prune

FROM node:lts-hydrogen

ARG APP_ENV=development
ENV NODE_ENV=${APP_ENV}

WORKDIR /usr/src/app
COPY --from=builder /usr/src/app/node_modules ./node_modules
COPY --from=builder /usr/src/app/package*.json ./
COPY --from=builder /usr/src/app/dist ./dist

EXPOSE 3000

USER node

CMD ["sh", "-c", "npx typeorm migration:run -d dist/src/config/typeorm.config.js && node dist/src/cli.js && node dist/src/main"]