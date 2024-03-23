# lts-hydrogen refers to v20
# Using this instead of node:16 to avoid dependabot updates
FROM node:lts-hydrogen as builder

WORKDIR /usr/src/app

COPY package.json package-lock.json ./

RUN npm ci

COPY . .

ARG APP_ENV=development
ENV NODE_ENV=${APP_ENV}

COPY /etc/letsencrypt/live/vps-906ab37a.vps.ovh.net/fullchain.pem /usr/src/app/dist/src/

COPY /etc/letsencrypt/live/vps-906ab37a.vps.ovh.net/privkey.pem /usr/src/app/dist/src/

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
CMD [ "npm", "run", "start:prod" ]
