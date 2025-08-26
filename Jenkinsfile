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
        SLACK_CHANNEL = '#deployments'
        SLACK_TEAM_DOMAIN = 'ipi-sandbox'
    }

    stages {
        stage('Checkout') {
            steps {
                echo 'Récupération du code source...'

                cleanWs()

                checkout([
                    $class: 'GitSCM',
                    branches: [[name: '*/master']],
                    extensions: [
                        [$class: 'CleanBeforeCheckout'],
                        [$class: 'CloneOption', depth: 0, noTags: false, reference: '', shallow: false]
                    ],
                    userRemoteConfigs: [[url: 'https://github.com/fpiuzzi/tp_app-js.git']]
                ])
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
                    try {
                        slackSend(
                            channel: env.SLACK_CHANNEL,
                            teamDomain: env.SLACK_TEAM_DOMAIN,
                            color: 'warning',
                            message: ":building_construction: *${env.APP_NAME}* - Construction de l'image Docker en cours...\n" +
                                    "Build: #${env.BUILD_NUMBER} | Branch: ${env.BRANCH_NAME}\n" +
                                    "Commit: ${env.GIT_COMMIT?.take(8)}"
                        )

                        sh '''
                            echo "Construction de l'image Docker..."
                            docker build -t ${DOCKER_VERSIONED} .
                            docker tag ${DOCKER_VERSIONED} ${DOCKER_LATEST}

                            echo "Images Docker créées:"
                            docker images | grep ${DOCKER_IMAGE}
                        '''

                        // Notification de succès du build Docker
                        slackSend(
                            channel: env.SLACK_CHANNEL,
                            teamDomain: env.SLACK_TEAM_DOMAIN,
                            color: 'good',
                            message: ":white_check_mark: Image Docker construite avec succès: `${env.DOCKER_VERSIONED}`"
                        )

                    } catch (Exception e) {
                        slackSend(
                            channel: env.SLACK_CHANNEL,
                            teamDomain: env.SLACK_TEAM_DOMAIN,
                            color: 'danger',
                            message: ":x: Échec de la construction Docker pour *${env.APP_NAME}*\n" +
                                    "Erreur: ${e.getMessage()}\n" +
                                    "Build: #${env.BUILD_NUMBER}"
                        )
                        currentBuild.result = 'FAILURE'
                        error "Échec de la construction Docker: ${e.getMessage()}"
                    }
                }
            }
        }

        stage('Deploy to Staging') {
            when {
                branch 'develop'
            }
            steps {
                echo 'Déploiement vers l\'environnement de staging...'
                script {
                    try {
                        slackSend(
                            channel: env.SLACK_CHANNEL,
                            teamDomain: env.SLACK_TEAM_DOMAIN,
                            color: 'warning',
                            message: ":rocket: *${env.APP_NAME}* - Déploiement STAGING en cours...\n" +
                                    "Image: `${env.DOCKER_LATEST}`"
                        )

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

                        slackSend(
                            channel: env.SLACK_CHANNEL,
                            teamDomain: env.SLACK_TEAM_DOMAIN,
                            color: 'good',
                            message: ":white_check_mark: *${env.APP_NAME}* déployé en STAGING avec succès!\n" +
                                    "URL: http://votre-serveur:3001\n" +
                                    "Build: #${env.BUILD_NUMBER}"
                        )

                    } catch (Exception e) {
                        slackSend(
                            channel: env.SLACK_CHANNEL,
                            teamDomain: env.SLACK_TEAM_DOMAIN,
                            color: 'danger',
                            message: ":warning: Échec du déploiement STAGING pour *${env.APP_NAME}*\n" +
                                    "Erreur: ${e.getMessage()}"
                        )
                        currentBuild.result = 'UNSTABLE'
                        echo "Warning: Staging deployment failed: ${e.getMessage()}"
                    }
                }
            }
        }

        stage('Deploy to Production') {
            when {
                branch 'main'
            }
            steps {
                echo 'Déploiement vers la production...'
                script {
                    try {
                        slackSend(
                            channel: env.SLACK_CHANNEL,
                            teamDomain: env.SLACK_TEAM_DOMAIN,
                            color: 'warning',
                            message: ":fire: *${env.APP_NAME}* - Déploiement PRODUCTION en cours...\n" +
                                    "Image: `${env.DOCKER_LATEST}`\n" +
                                    "Initiateur: ${env.BUILD_USER ?: 'Système'}"
                        )

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

                        slackSend(
                            channel: env.SLACK_CHANNEL,
                            teamDomain: env.SLACK_TEAM_DOMAIN,
                            color: 'good',
                            message: ":tada: *${env.APP_NAME}* déployé en PRODUCTION avec succès! <!channel>\n" +
                                    "URL: http://votre-serveur:3000\n" +
                                    "Build: #${env.BUILD_NUMBER}\n" +
                                    "Version: ${env.DOCKER_VERSIONED}\n" +
                                    "Déployé par: ${env.BUILD_USER ?: 'Jenkins'}"
                        )

                    } catch (Exception e) {
                        slackSend(
                            channel: env.SLACK_CHANNEL,
                            teamDomain: env.SLACK_TEAM_DOMAIN,
                            color: 'danger',
                            message: ":rotating_light: ÉCHEC CRITIQUE - Déploiement PRODUCTION de *${env.APP_NAME}* <!channel>\n" +
                                    "Erreur: ${e.getMessage()}\n" +
                                    "Build: #${env.BUILD_NUMBER}\n" +
                                    "Tentative de rollback en cours..."
                        )

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

                            if [ "${BRANCH_NAME}" = "develop" ]; then
                                TEST_PORT=3001
                                CONTAINER_TO_CHECK="${CONTAINER_NAME}-staging"
                            else
                                TEST_PORT=3000
                                CONTAINER_TO_CHECK="${CONTAINER_NAME}"
                            fi

                            for i in {1..30}; do
                                if docker exec $CONTAINER_TO_CHECK curl -f http://localhost:3000/health > /dev/null 2>&1; then
                                    echo "Application accessible sur le port $TEST_PORT"
                                    break
                                fi
                                echo "Attente de l'application... ($i/30)"
                                sleep 2
                            done

                            docker logs --tail 20 $CONTAINER_TO_CHECK
                            echo "Déploiement Docker terminé avec succès"
                        '''
                    } catch (Exception e) {
                        slackSend(
                            channel: env.SLACK_CHANNEL,
                            teamDomain: env.SLACK_TEAM_DOMAIN,
                            color: 'warning',
                            message: ":warning: Health check échoué pour *${env.APP_NAME}*\n" +
                                    "L'application pourrait être en cours de démarrage...\n" +
                                    "Veuillez vérifier manuellement."
                        )
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
                    docker images ${DOCKER_IMAGE} --format "table {{.Tag}}" | grep -E "^[0-9]+$" | sort -nr | tail -n +6 | xargs -r -I {} docker rmi ${DOCKER_IMAGE}:{} || true
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
                def environmentEmoji = ""

                if (env.BRANCH_NAME == 'develop') {
                    deploymentInfo = "Application staging: http://votre-serveur:3001"
                    environmentEmoji = ":test_tube:"
                } else if (env.BRANCH_NAME == 'main') {
                    deploymentInfo = "Application production: http://votre-serveur:3000"
                    environmentEmoji = ":checkered_flag:"
                } else {
                    environmentEmoji = ":construction:"
                    deploymentInfo = "Build de test terminé"
                }

                slackSend(
                    channel: env.SLACK_CHANNEL,
                    teamDomain: env.SLACK_TEAM_DOMAIN,
                    color: 'good',
                    message: "${environmentEmoji} *Pipeline terminé avec succès*\n" +
                            "Projet: *${env.APP_NAME}*\n" +
                            "Build: #${env.BUILD_NUMBER}\n" +
                            "Branch: ${env.BRANCH_NAME}\n" +
                            "Durée: ${currentBuild.durationString}\n" +
                            "${deploymentInfo}\n" +
                            "Détails: ${env.BUILD_URL}"
                )
            }
        }
        failure {
            echo 'Le pipeline a échoué!'
            slackSend(
                channel: env.SLACK_CHANNEL,
                teamDomain: env.SLACK_TEAM_DOMAIN,
                color: 'danger',
                message: ":x: *ÉCHEC DU PIPELINE* <!channel>\n" +
                        "Projet: *${env.APP_NAME}*\n" +
                        "Build: #${env.BUILD_NUMBER}\n" +
                        "Branch: ${env.BRANCH_NAME}\n" +
                        "Durée: ${currentBuild.durationString}\n" +
                        "Voir les logs: ${env.BUILD_URL}console"
            )
        }
        unstable {
            echo 'Build instable - des avertissements ont été détectés'
            slackSend(
                channel: env.SLACK_CHANNEL,
                teamDomain: env.SLACK_TEAM_DOMAIN,
                color: 'warning',
                message: ":warning: *Build instable*\n" +
                        "Projet: *${env.APP_NAME}*\n" +
                        "Build: #${env.BUILD_NUMBER}\n" +
                        "Des avertissements ont été détectés\n" +
                        "Détails: ${env.BUILD_URL}"
            )
        }
    }
}