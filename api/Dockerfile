FROM node:lts-hydrogen as builder
WORKDIR /usr/src/app

# Set up pnpm
ENV PNPM_HOME="/root/.local/share/pnpm"
ENV PATH="${PATH}:${PNPM_HOME}"
RUN corepack enable && corepack prepare pnpm@8.15.3 --activate
RUN pnpm config set store-dir ~/.pnpm-store

# Copy package files and install ALL dependencies for development
COPY package.json ./
ENV NODE_ENV=development
RUN pnpm install --no-frozen-lockfile

COPY . .

# Build the application
RUN pnpm exec nest build

# Clean up development dependencies for production
ENV NODE_ENV=production
RUN pnpm prune --prod

FROM node:lts-hydrogen
WORKDIR /usr/src/app

# Set up pnpm in production image
ENV PNPM_HOME="/root/.local/share/pnpm"
ENV PATH="${PATH}:${PNPM_HOME}"
RUN corepack enable && corepack prepare pnpm@8.15.3 --activate

ENV NODE_ENV=production \
    NODE_OPTIONS="--max-old-space-size=2048" \
    TZ=UTC

RUN apt-get update && apt-get install -y --no-install-recommends dumb-init curl \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/cache/apk/*

COPY --from=builder --chown=node:node /usr/src/app/dist ./dist
COPY --from=builder --chown=node:node /usr/src/app/node_modules ./node_modules
COPY --chown=node:node package.json ./

USER node

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=30s \
    CMD curl -f http://localhost:3000/api/v1/health || exit 1

ENTRYPOINT ["dumb-init", "--"]
CMD [ "pnpm", "start:prod" ]
