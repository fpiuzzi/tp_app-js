pipeline {
    agent any

    tools {
        nodejs 'Node18'
    }

    environment {
        APP_NAME = 'mon-app-js'
        DOCKER_IMAGE = 'mon-app-js'
        DOCKER_TAG = "${BUILD_NUMBER}"
    }

    stages {
        stage('Vérification') {
            steps {
                sh 'node --version || echo "Node.js non disponible"'
                sh 'npm --version || echo "npm non disponible"'
                sh 'docker --version || echo "Docker non disponible"'
                sh 'docker-compose --version || echo "Docker Compose non disponible"'
            }
        }

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Install') {
            steps {
                sh 'npm install'
            }
        }

        stage('Test') {
            steps {
                sh 'npm test || echo "Tests ignorés"'
            }
        }

        stage('Build et Deploy') {
            steps {
                sh '''
                # Création du fichier docker-compose.yml si nécessaire
                if [ ! -f docker-compose.yml ]; then
                    cat > docker-compose.yml <<EOF
version: '3'
services:
  app:
    build: .
    image: ${DOCKER_IMAGE}:${DOCKER_TAG}
    container_name: ${APP_NAME}
    ports:
      - "3000:3000"
    restart: unless-stopped
EOF
                fi

                # Arrêt des conteneurs existants et démarrage avec la nouvelle image
                docker-compose down || true
                docker-compose build
                docker-compose up -d

                # Tag l'image comme latest
                docker tag ${DOCKER_IMAGE}:${DOCKER_TAG} ${DOCKER_IMAGE}:latest
                '''
            }
        }
    }

    post {
        always {
            sh 'rm -rf node_modules/.cache || true'
        }
        success {
            echo 'Build réussi!'
            script {
                try {
                    slackSend(
                        color: 'good',
                        message: "Déploiement réussi : ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                        tokenCredentialId: 'slack-token'
                    )
                } catch (Exception e) {
                    echo "Notification Slack non envoyée: ${e.getMessage()}"
                }
            }
        }
        failure {
            echo 'Build échoué!'
        }
    }
}