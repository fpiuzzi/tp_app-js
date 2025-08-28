pipeline {
    agent {
        docker {
            image 'node:18'
            args '-v /var/run/docker.sock:/var/run/docker.sock -u root'
        }
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
        STAGING_PORT = '3001'
        PRODUCTION_PORT = '3000'
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
                sh """
                    npm install
                    node --version
                    npm --version
                """
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
                sh """
                    echo "Vérification des dépendances..."
                    npm audit --audit-level=high || true
                """
            }
        }

        stage('Build Docker Image') {
            steps {
                echo 'Construction de l\'image Docker...'
                script {
                    try {
                        sh "docker build -t ${DOCKER_VERSIONED} ."
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
                anyOf {
                    branch 'develop'
                    branch 'master'
                }
            }
            steps {
                echo 'Déploiement vers l\'environnement de staging...'
                sh """
                    # Arrêter le conteneur existant s'il existe
                    docker stop ${CONTAINER_NAME}-staging || true
                    docker rm ${CONTAINER_NAME}-staging || true

                    # Lancer le nouveau conteneur
                    docker run -d --name ${CONTAINER_NAME}-staging -p ${STAGING_PORT}:3000 ${DOCKER_LATEST}

                    echo "Application déployée en staging sur le port ${STAGING_PORT}"
                """
            }
            post {
                success {
                    echo 'Vérification de santé du déploiement staging...'
                    sh """
                        # Attente pour que l'application démarre
                        sleep 10

                        # Vérification du statut HTTP
                        STATUS=\$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${STAGING_PORT}/health || echo 'down')
                        if [ "\$STATUS" = "200" ]; then
                            echo "L'application staging répond correctement"
                        else
                            echo "L'application staging ne répond pas correctement (code: \$STATUS)"
                            exit 1
                        fi
                    """
                }
            }
        }

        stage('Deploy to Production') {
            when {
                branch 'master'
            }
            steps {
                echo 'Déploiement vers la production...'
                input message: 'Voulez-vous déployer en production?'
                sh """
                    # Arrêter le conteneur existant s'il existe
                    docker stop ${CONTAINER_NAME}-prod || true
                    docker rm ${CONTAINER_NAME}-prod || true

                    # Lancer le nouveau conteneur
                    docker run -d --name ${CONTAINER_NAME}-prod -p ${PRODUCTION_PORT}:3000 ${DOCKER_LATEST}

                    echo "Application déployée en production sur le port ${PRODUCTION_PORT}"
                """
            }
            post {
                success {
                    echo 'Vérification de santé du déploiement production...'
                    sh """
                        # Attente pour que l'application démarre
                        sleep 10

                        # Vérification du statut HTTP
                        STATUS=\$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${PRODUCTION_PORT}/health || echo 'down')
                        if [ "\$STATUS" = "200" ]; then
                            echo "L'application production répond correctement"
                        else
                            echo "L'application production ne répond pas correctement (code: \$STATUS)"
                            exit 1
                        fi
                    """
                }
            }
        }

        stage('Cleanup Old Images') {
            steps {
                echo 'Nettoyage des anciennes images...'
                sh """
                    # Garder uniquement les images récentes
                    docker image prune -af --filter "until=24h"

                    # Afficher les images restantes
                    docker images | grep ${DOCKER_IMAGE} || true
                """
            }
        }
    }

    post {
        always {
            echo 'Nettoyage des ressources temporaires...'
            sh """
                rm -rf node_modules/.cache || true
            """
        }
        success {
            echo 'Pipeline exécuté avec succès!'
            script {
                try {
                    slackSend(color: 'good', message: "Déploiement réussi : ${env.JOB_NAME} #${env.BUILD_NUMBER}")
                } catch (Exception e) {
                    echo "Note: Notification Slack non envoyée. Vérifiez la configuration des credentials Slack."
                }
            }
        }
        failure {
            echo 'Le pipeline a échoué!'
            script {
                try {
                    slackSend(color: 'danger', message: "Échec du déploiement : ${env.JOB_NAME} #${env.BUILD_NUMBER}")
                } catch (Exception e) {
                    echo "Note: Notification Slack non envoyée. Vérifiez la configuration des credentials Slack."
                }
            }
        }
    }
}