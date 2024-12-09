# Define the base image with Node.js 18 and Alpine
FROM node:18-alpine AS base

# Install system dependencies required by Node.js or native addons
RUN apk add --no-cache libc6-compat

# Set the working directory in the container
WORKDIR /app

# Enable pnpm using corepack and install dependencies
RUN corepack enable pnpm
COPY package.json pnpm-lock.yaml* ./
RUN if [ -f pnpm-lock.yaml ]; then pnpm install --frozen-lockfile; \
    else echo "Lockfile not found." && exit 1; \
    fi

# Copy the application code and build the Next.js project
FROM base AS builder
COPY . .
RUN pnpm run build

# Prepare the runner stage for running the application
FROM base AS runner

# Set environment variables for production
ENV NODE_ENV production
ENV PORT 3000
ENV NEXT_TELEMETRY_DISABLED 1

# Create a non-root user and switch to it for security
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs
USER nextjs

# Copy the built files from the builder stage
COPY --from=builder /app/next .next
COPY --from=builder /app/public public

# Expose the port the app will run on
EXPOSE 3000

# Run database migrations and then start the Next.js server
CMD HOSTNAME="0.0.0.0" node server.js
