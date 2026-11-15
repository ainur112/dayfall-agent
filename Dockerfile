FROM node:22-bookworm-slim AS build
RUN apt-get update && apt-get install -y --no-install-recommends unzip && rm -rf /var/lib/apt/lists/*
COPY dayfall-agent-upload.zip /tmp/source.zip
RUN unzip -q /tmp/source.zip -d /opt
WORKDIR /opt/dayfall-agent
ENV TMPDIR=/tmp
RUN npm ci && npm run build && npm test && npm prune --omit=dev
FROM node:22-bookworm-slim
WORKDIR /app
ENV NODE_ENV=production PORT=3000 REPLAY_DIR=/app/data/replay
COPY --from=build /opt/dayfall-agent/node_modules ./node_modules
COPY --from=build /opt/dayfall-agent/dist ./dist
COPY --from=build /opt/dayfall-agent/package.json /opt/dayfall-agent/gatekeeper.wasm /opt/dayfall-agent/gatekeeper_final.zkey /opt/dayfall-agent/verification_key.json ./
RUN mkdir -p /app/data/replay && chown -R node:node /app/data
USER node
EXPOSE 3000
CMD ["node", "dist/main.js"]
