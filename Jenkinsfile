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
                    npm ci
                    npm install --save-dev jest-junit
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

        stage('Code Quality Check') {
            steps {
                echo 'Vérification de la qualité du code...'
                sh '''
                    echo "Vérification de la syntaxe JavaScript..."
                    find src -name "*.js" -exec node -c {} \\;
                    echo "Vérification terminée"
                '''
            }
        }

        stage('Build Application') {
            steps {
                echo 'Construction de l\'application...'
                sh '''
                    npm run build
                    ls -la dist/
                '''
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
                    writeFile file: 'Dockerfile', text: '''
        FROM node:18-alpine
        WORKDIR /app
        COPY package*.json ./
        RUN npm ci
        COPY . .
        RUN npm run build
        RUN npm prune --production
        EXPOSE 3000
        CMD ["node", "dist/index.js"]
        '''
                    sh 'docker build -t ${DOCKER_VERSIONED} . && docker tag ${DOCKER_VERSIONED} ${DOCKER_LATEST}'
                }
            }
        }

        stage('Deploy to Staging') {
            steps {
                echo 'Déploiement vers l\'environnement de staging...'
                script {
                    try {
                        sh '''
                            echo "Arrêt du conteneur staging existant..."
                            docker stop ${CONTAINER_NAME}-staging || true
                            docker rm ${CONTAINER_NAME}-staging || true

                            echo "Démarrage du conteneur staging..."
                            docker run -d \\
                                --name ${CONTAINER_NAME}-staging \\
                                --restart unless-stopped \\
                                -p 3001:3000 \\
                                -e NODE_ENV=staging \\
                                -e APP_NAME=${APP_NAME} \\
                                ${DOCKER_LATEST}

                            echo "Vérification du déploiement staging..."
                            sleep 10
                            docker ps | grep ${CONTAINER_NAME}-staging
                        '''
                    } catch (Exception e) {
                        currentBuild.result = 'UNSTABLE'
                        echo "Warning: Staging deployment failed: ${e.getMessage()}"
                    }
                }
            }
        }

        stage('Deploy to Production') {
            when {
                branch 'master'
            }
            steps {
                echo 'Déploiement vers la production...'
                script {
                    try {
                        sh '''
                            echo "Sauvegarde de l'ancien conteneur..."
                            if docker ps -q -f name=${CONTAINER_NAME}; then
                                echo "Arrêt du conteneur de production existant..."
                                docker stop ${CONTAINER_NAME}
                                docker rename ${CONTAINER_NAME} ${CONTAINER_NAME}-backup-$(date +%Y%m%d_%H%M%S) || true
                            fi

                            echo "Démarrage du nouveau conteneur de production..."
                            docker run -d \\
                                --name ${CONTAINER_NAME} \\
                                --restart unless-stopped \\
                                -p 3000:3000 \\
                                -e NODE_ENV=production \\
                                -e APP_NAME=${APP_NAME} \\
                                -v /var/log/${APP_NAME}:/app/logs \\
                                ${DOCKER_LATEST}

                            echo "Vérification du déploiement production..."
                            sleep 15
                            docker ps | grep ${CONTAINER_NAME}
                        '''
                    } catch (Exception e) {
                        // Rollback en cas d'échec
                        sh '''
                            echo "Échec du déploiement, tentative de rollback..."
                            docker stop ${CONTAINER_NAME} || true
                            docker rm ${CONTAINER_NAME} || true

                            BACKUP_CONTAINER=$(docker ps -a --format "table {{.Names}}" | grep ${CONTAINER_NAME}-backup | head -n1)
                            if [ ! -z "$BACKUP_CONTAINER" ]; then
                                echo "Restauration du conteneur de sauvegarde: $BACKUP_CONTAINER"
                                docker rename $BACKUP_CONTAINER ${CONTAINER_NAME}
                                docker start ${CONTAINER_NAME}
                            fi
                        '''
                        error "Deployment failed: ${e.getMessage()}"
                    }
                }
            }
        }

        stage('Health Check') {
            steps {
                echo 'Vérification de santé de l\'application...'
                script {
                    try {
                        sh '''
                            echo "Test de connectivité sur le conteneur..."

                            # Déterminer le port selon l'environnement
                            if [ "${BRANCH_NAME}" = "develop" ]; then
                                TEST_PORT=3001
                                CONTAINER_TO_CHECK="${CONTAINER_NAME}-staging"
                            else
                                TEST_PORT=3000
                                CONTAINER_TO_CHECK="${CONTAINER_NAME}"
                            fi

                            # Attendre que l'application soit prête
                            for i in {1..30}; do
                                if docker exec $CONTAINER_TO_CHECK curl -f http://localhost:3000/health > /dev/null 2>&1; then
                                    echo "Application accessible sur le port $TEST_PORT"
                                    break
                                fi
                                echo "Attente de l'application... ($i/30)"
                                sleep 2
                            done

                            # Vérification finale
                            docker logs --tail 20 $CONTAINER_TO_CHECK
                            echo "Déploiement Docker terminé avec succès"
                        '''
                    } catch (Exception e) {
                        currentBuild.result = 'UNSTABLE'
                        echo "Warning: Health check failed: ${e.getMessage()}"
                    }
                }
            }
        }

        stage('Cleanup Old Images') {
            steps {
                echo 'Nettoyage des anciennes images Docker...'
                sh '''
                    echo "Nettoyage des images Docker obsolètes..."
                    # Garder les 5 dernières versions
                    docker images ${DOCKER_IMAGE} --format "table {{.Tag}}" | grep -E "^[0-9]+$" | sort -nr | tail -n +6 | xargs -r -I {} docker rmi ${DOCKER_IMAGE}:{} || true

                    # Nettoyage des conteneurs arrêtés
                    docker container prune -f

                    echo "Nettoyage terminé"
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
            script {
                def deploymentInfo = ""
                if (env.BRANCH_NAME == 'develop') {
                    deploymentInfo = "Application staging disponible sur: http://[VOTRE_SERVEUR]:3001"
                } else if (env.BRANCH_NAME == 'main') {
                    deploymentInfo = "Application production disponible sur: http://[VOTRE_SERVEUR]:3000"
                }

                emailext (
                    subject: "Build Success: ${env.JOB_NAME} - ${env.BUILD_NUMBER}",
                    body: """
                        Le déploiement de ${env.JOB_NAME} s'est terminé avec succès.

                        Build: ${env.BUILD_NUMBER}
                        Branch: ${env.BRANCH_NAME}
                        Docker Image: ${env.DOCKER_VERSIONED}

                        ${deploymentInfo}

                        Voir les détails: ${env.BUILD_URL}
                    """,
                    to: "${env.CHANGE_AUTHOR_EMAIL}"
                )
            }
        }
        failure {
            echo 'Le pipeline a échoué!'
            emailext (
                subject: "Build Failed: ${env.JOB_NAME} - ${env.BUILD_NUMBER}",
                body: """
                    Le déploiement de ${env.JOB_NAME} a échoué.

                    Build: ${env.BUILD_NUMBER}
                    Branch: ${env.BRANCH_NAME}

                    Voir les détails: ${env.BUILD_URL}
                """,
                to: "${env.CHANGE_AUTHOR_EMAIL}"
            )
        }
        unstable {
            echo 'Build instable - des avertissements ont été détectés'
        }
    }
}