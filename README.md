# CI/CD avec Jenkins, Docker Registry local & intégrations (Slack, plugins)

Ce document décrit tout ce que j'ai réalisé pour builder et pousser l’image `mon-app-js` vers un **Docker local**, via une pipeline Jenkins. Il couvre les plugins, les credentials, Build et les notifications Slack.


## 1) Prérequis sur l’agent Jenkins

- Docker (avec accès au daemon pour l’utilisateur Jenkins)
- `docker buildx` disponible (`docker buildx version`)
- Git installé (ex. `git 2.39+`)
- Accès réseau au registry local sur `127.0.0.1:5000`

## 2) Plugins Jenkins utilisés / utiles

- **Pipeline**
- **Git** (SCM)
- **Node Js**
- **Blue Ocean**
- **Docker Pipeline** (utilitaires Docker)
- **Slack Notification Plugin** (notifications)

## 3) Dépôt & Jenkinsfile

- Dépôt Git : `https://github.com/fpiuzzi/tp_app-js.git`
- Branche : `master`
- Le job Jenkins est une pipeline qui lit le `Jenkinsfile` à la racine.

## 4) Installation du plugin Node Js

Ce plugin permet à Jenkins :

- D'exécuter les commandes npm install, npm run build ou npm test dans la pipeline,

- De s'assurer que l’environnement Jenkins utilise la bonne version de Node pour builder l’application.

Pour ce faire il faut d'abord installer le plugin `Node Js Plugin` et le configurer avec la version souhaité dans la partie Tools de Jenkins en indiquand la version ainsi qu'un nom (exemple node18) qui devra être utilisé à l'identique dans la pipeline jenkins

## 5) Fichiers Docker du projet

### Dockerfile.jenkins

Image personnalisée Jenkins avec Docker, build, git, npm. Permet d’exécuter les pipelines CI/CD.

### Dockerfile

Construit l’application Node.js : installe les dépendances, build, copie dans Nginx pour servir les fichiers statiques.

### docker-compose.yml

Orchestre Jenkins, registry Docker local, app Node, Slack. Simplifie le démarrage de l’environnement.

## 6) Notifications Slack

### Configuration coté Slack

1.  Sur Slack API Apps
2.  Creation New App.
3.  Ajout d'un Bot et il faut lui donner les droits suivants : chat:write.
4.  SCrée un workspace et récupère le Bot Token (xoxb-... pour la création côté crédential Jenkins).
5. Invitation du bot dans le channel désiré : /invite @jenkins-notifier.

### Configuration côté Jenkins

1. Installer **Slack Notification Plugin**.
2. *Manage Jenkins* → *Configure System* → **Global Slack Notifier** :
   - *Team Domain / Workspace*
   - *Integration Token Credential ID* (ajoute une **Secret text** avec le Bot Token crée coté Slack)
   - *Channel* dédié

## 7) Docker Registry local

L'utilisation de `registry:2` en local sur `127.0.0.1:5000` permettra de lancer l'application depuis l'image Docker

## 8) Gitea

Création d'un docker-compose-gitea.yml à la racine du projet et lancement `docker compose -f docker-compose-gitea.yml up -d`

Ouvre `http://localhost:3000` pour lancer Gitea

Il faut créer un jeton d'accès coté Gitea avec lecture sur repository

Une fois le jeton récupéré il faudra créer un token coté Jenkins pour faire le lien

Token avec Id/password

Une fois réalisé une nouvelle pipeline coté Jenkins peut être crée en utilisant gitea plutôt que Git



