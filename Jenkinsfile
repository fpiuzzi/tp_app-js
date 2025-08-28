pipeline {
    agent any

    tools {
        nodejs 'node18'
    }

    environment {
        NODE_VERSION = '18'
        APP_NAME = 'mon-app-js'
        DEPLOY_DIR = '/var/www/html/mon-app'
        DOCKER_IMAGE = 'mon-app-js'
        DOCKER_TAG = "${BUILD_NUMBER}"
        DOCKER_LATEST = "${DOCKER_IMAGE}:latest"
        DOCKER_VERSIONED = "${DOCKER_IMAGE}:${DOCKER_TAG}"
        CONTAINER_NAME = 'mon-app-js-container'
    }

    stages {
        stage('Checkout') {
            steps {
                echo 'Récupération du code source...'
                checkout scm
            }
        }

        stage('Install Dependencies') {
            steps {
                echo 'Installation des dépendances Node.js...'
                sh '''
                    npm install
                    node --version
                    npm --version
                '''
            }
        }

        stage('Run Tests') {
            steps {
                echo 'Exécution des tests...'
                sh 'npm test'
            }
            post {
                always {
                    junit testResults: '**/test-results.xml', allowEmptyResults: true
                }
            }
        }

        stage('Security Scan') {
            steps {
                echo 'Analyse de sécurité...'
                sh '''
                    echo "Vérification des dépendances..."
                    npm audit --audit-level=high
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                echo 'Construction de l\'image Docker...'
                script {
                    try {
                        // Utilisation de la syntaxe du plugin Docker
                        docker.build("${DOCKER_VERSIONED}", ".")
                        sh "docker tag ${DOCKER_VERSIONED} ${DOCKER_LATEST}"

                        echo "Image Docker construite avec succès: ${DOCKER_VERSIONED}"
                    } catch (Exception e) {
                        echo "Échec de la construction Docker"
                        error "Échec de la construction Docker: ${e.getMessage()}"
                    }
                }
            }
        }

        stage('Deploy to Staging') {
            when {
                expression { env.BRANCH_NAME == 'develop' || env.BRANCH_NAME == 'master' }
            }
            steps {
                echo 'Déploiement vers l\'environnement de staging...'
                sh '''
                    # Arrêter le conteneur existant s'il existe
                    docker stop ${CONTAINER_NAME}-staging || true
                    docker rm ${CONTAINER_NAME}-staging || true

                    # Lancer le nouveau conteneur
                    docker run -d --name ${CONTAINER_NAME}-staging -p 3001:3000 ${DOCKER_LATEST}

                    echo "Application déployée en staging sur le port 3001"
                '''
            }
        }

        stage('Deploy to Production') {
            when {
                branch 'master'
            }
            steps {
                echo 'Déploiement vers la production...'
                input message: 'Voulez-vous déployer en production?'
                sh '''
                    # Arrêter le conteneur existant s'il existe
                    docker stop ${CONTAINER_NAME}-prod || true
                    docker rm ${CONTAINER_NAME}-prod || true

                    # Lancer le nouveau conteneur
                    docker run -d --name ${CONTAINER_NAME}-prod -p 3000:3000 ${DOCKER_LATEST}

                    echo "Application déployée en production sur le port 3000"
                '''
            }
        }

        stage('Health Check') {
            steps {
                echo 'Vérification de santé de l\'application...'
                sh '''
                    # Attente pour que l'application démarre
                    sleep 10

                    # Vérification du statut HTTP
                    if [ "$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/health || echo 'down')" = "200" ]; then
                        echo "L'application répond correctement"
                    else
                        echo "L'application ne répond pas correctement"
                        exit 1
                    fi
                '''
            }
        }

        stage('Cleanup Old Images') {
            steps {
                echo 'Nettoyage des anciennes images...'
                sh '''
                    # Garder uniquement les 3 dernières images
                    docker image prune -af --filter "until=24h"

                    # Afficher les images restantes
                    docker images | grep ${DOCKER_IMAGE}
                '''
            }
        }
    }

    post {
        always {
            echo 'Nettoyage des ressources temporaires...'
            sh '''
                rm -rf node_modules/.cache
                rm -rf staging
            '''
        }
        success {
            echo 'Pipeline exécuté avec succès!'
            slackSend(color: 'good', message: "Déploiement réussi : ${env.JOB_NAME} #${env.BUILD_NUMBER}")
        }
        failure {
            echo 'Le pipeline a échoué!'
            slackSend(color: 'danger', message: "Échec du déploiement : ${env.JOB_NAME} #${env.BUILD_NUMBER}")
        }
    }
}