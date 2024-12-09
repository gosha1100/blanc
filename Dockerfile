# Stage 1: Base image
FROM node:18-alpine AS base
WORKDIR /app

# Install dependencies needed for builds
RUN apk add --no-cache libc6-compat

# Stage 2: Dependencies installation
FROM base AS deps
WORKDIR /app

# Copy package manager lockfiles and install dependencies
COPY package.json yarn.lock* package-lock.json* pnpm-lock.yaml* ./
RUN \
  if [ -f yarn.lock ]; then yarn install --frozen-lockfile; \
  elif [ -f package-lock.json ]; then npm ci; \
  elif [ -f pnpm-lock.yaml ]; then corepack enable pnpm && pnpm i --frozen-lockfile; \
  else echo "No lockfile found, cannot install dependencies" && exit 1; \
  fi

# Stage 3: Build the application
FROM base AS builder
WORKDIR /app

# Copy dependencies and source code
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Build the Next.js application
RUN npm run build

# Stage 4: Production-ready application
FROM base AS runner
WORKDIR /app

ENV NODE_ENV=production

# Add user for security
RUN addgroup --system --gid 1001 nodejs \
  && adduser --system --uid 1001 nextjs

# Copy necessary files from the build stage
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/package.json ./

# Adjust permissions
RUN chown -R nextjs:nodejs /app

USER nextjs

EXPOSE 3000
ENV PORT=3000

# Start the application
CMD ["node", "server.js"]
