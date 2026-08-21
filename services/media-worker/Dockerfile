FROM node:22.14.0-alpine3.21

RUN apk add --no-cache ffmpeg=6.1.2-r1 \
  && addgroup -S svnly \
  && adduser -S -G svnly -h /app svnly

WORKDIR /app
COPY --chown=svnly:svnly package.json server.mjs ./
USER svnly
ENV PORT=8080 NODE_ENV=production
EXPOSE 8080
CMD ["node", "server.mjs"]
