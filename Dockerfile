FROM node:18-alpine AS base
RUN corepack enable


FROM base AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /app
COPY package.json .yarnrc.yml yarn.lock .pnp* ./
COPY .yarn ./.yarn
RUN \
  if [ -f yarn.lock ]; then yarn --frozen-lockfile; \
  else echo "Lockfile not found." && exit 1; \
  fi


FROM base AS builder
WORKDIR /app
COPY . .
COPY --from=deps /app/.yarn ./.yarn
COPY --from=deps /app/.pnp* /app/yarn.lock /app/package.json ./
RUN apk add jq \
    && yarn build \
    && echo $(cat package.json | jq 'del(.devDependencies)') > package.json \
    && yarn

FROM base AS runner
ENV NODE_ENV production
ENV PORT 3000
RUN addgroup --system --gid 1001 nodejs \
    && adduser --system --uid 1001 nextjs
USER nextjs
WORKDIR /app
COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next ./.next
COPY --from=builder --chown=nextjs:nodejs /app/package.json /app/yarn.lock /app/.pnp* ./
COPY --from=builder --chown=nextjs:nodejs /app/.yarn ./.yarn

EXPOSE 3000
CMD ["yarn", "start"]
