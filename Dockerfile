FROM node:22
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build
EXPOSE 3000
ENV HOST=0.0.0.0
ENV PORT=3000
CMD ["npm", "run", "preview"]