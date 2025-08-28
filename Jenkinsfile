pipeline {
    agent any

    tools {
        nodejs 'Node18'
    }

    stages {
        stage('Build') {
            steps {
                echo 'Compilation...'
            }
        }

        stage('Test') {
            steps {
                echo 'Tests...'
            }
        }

        stage('Deploy') {
            steps {
                echo 'Déploiement...'
            }
        }
    }
}