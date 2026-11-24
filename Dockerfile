FROM node:22-alpine AS build
WORKDIR /app

COPY web/package.json web/package-lock.json ./
RUN npm ci

COPY web/ ./
RUN DB_HOST=127.0.0.1 \
    DB_PORT=3306 \
    DB_NAME=clube_reservas \
    DB_USER=build \
    DB_PASSWORD=build-only \
    JWT_SECRET=build-only-secret-not-for-runtime-00000000 \
    COOKIE_SECURE=false \
    npm run build -- --webpack

FROM node:22-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production
ENV PORT=3000
ENV HOSTNAME=0.0.0.0

COPY --from=build /app/package.json /app/package-lock.json ./
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/.next ./.next
COPY --from=build /app/public ./public
COPY --from=build /app/proxy.ts ./proxy.ts

EXPOSE 3000
CMD ["npm", "start"]
