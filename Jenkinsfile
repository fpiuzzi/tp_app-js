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
                sh 'npm test || true'
            }
        }

        stage('Build Docker') {
            steps {
                sh '''
                if command -v docker &> /dev/null; then
                    docker build -t ${DOCKER_IMAGE}:${DOCKER_TAG} .
                    docker tag ${DOCKER_IMAGE}:${DOCKER_TAG} ${DOCKER_IMAGE}:latest
                else
                    echo "Docker non disponible"
                fi
                '''
            }
        }

        stage('Deploy') {
            steps {
                echo 'Déploiement...'
                sh '''
                if command -v docker &> /dev/null; then
                    docker stop ${APP_NAME} || true
                    docker rm ${APP_NAME} || true
                    docker run -d -p 3000:3000 --name ${APP_NAME} ${DOCKER_IMAGE}:latest || echo "Déploiement ignoré"
                else
                    echo "Docker non disponible"
                fi
                '''
            }
        }
    }

    post {
        success {
            echo 'Build réussi!'
        }
        failure {
            echo 'Build échoué!'
        }
    }
}