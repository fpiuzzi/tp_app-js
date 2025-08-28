FROM node:18-alpine AS builder

WORKDIR /app

# Copier les fichiers de dépendances
COPY package*.json ./

# Installer les dépendances
RUN npm ci

# Copier le reste du code source
COPY . .

# Construire l'application
RUN npm run build

# Étape de production
FROM node:18-alpine

WORKDIR /app

# Copier les dépendances de production et les fichiers de build
COPY --from=builder /app/package*.json ./
RUN npm ci --only=production
COPY --from=builder /app/dist ./dist

# Configuration pour la production
ENV NODE_ENV=production

# Utilisateur non-root pour plus de sécurité
USER node

# Port exposé par l'application
EXPOSE 3000

# Commande de démarrage
CMD ["node", "dist/server.js"]