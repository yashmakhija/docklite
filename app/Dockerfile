FROM node:14-slim
ENV PORT=3000
ENV NODE_ENV=production

WORKDIR /app
COPY package.json ./
RUN npm install
COPY server.js .

CMD node server.js