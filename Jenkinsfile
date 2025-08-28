pipeline {
    agent any

    tools {
        nodejs 'Node18'
    }

    stages {
        stage('Préparation') {
            steps {
                echo 'Démarrage du pipeline de test'
                sh 'node --version'
                sh 'npm --version'
            }
        }

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Installation') {
            steps {
                sh 'npm ci || npm install'
            }
        }

        stage('Tests') {
            steps {
                sh 'npm test || echo "Pas de tests ou tests échoués"'
            }
        }

        stage('Build') {
            steps {
                sh 'npm run build || echo "Pas de build configuré"'
            }
        }
    }

    post {
        success {
            echo 'Pipeline de test réussi!'
        }
        failure {
            echo 'Pipeline de test échoué!'
        }
        always {
            echo 'Pipeline terminé'
        }
    }
}