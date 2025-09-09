pipeline {
  agent any

  tools {
    nodejs 'node18'
  }

  environment {
    APP_NAME              = 'mon-app-js'
    CONTAINER_NAME        = 'mon-app-js-container'
    STAGING_PORT          = '3001'
    PRODUCTION_PORT       = '3000'
    REGISTRY_URL          = ''
    IMAGE_REPO            = 'monuser/mon-app-js'
    REGISTRY_CRED         = 'REGISTRY_CRED'
    GIT_SHORT             = ''
    IMAGE_TAG             = ''
    IMAGE_LATEST          = 'latest'
    PATH                  = "${env.PATH}:/usr/local/bin"
    COMPOSE_PROJECT_NAME  = "${env.JOB_NAME}-${env.BUILD_NUMBER}"
  }

  options {
    timestamps()
    skipDefaultCheckout(true)
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
        script {
          env.GIT_SHORT = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
          env.IMAGE_TAG = "${env.GIT_SHORT}-${env.BUILD_NUMBER}"
        }
      }
    }

    stage('Vérification Docker/Compose') {
      steps {
        sh '''
          docker version
          docker info
          docker compose version
          echo "DOCKER_HOST=${DOCKER_HOST:-<unset>}"
        '''
      }
    }

    stage('Build image (docker compose)') {
      steps {
        sh '''
          docker compose build --pull
          SRC_IMAGE="${APP_NAME}"
          PREFIX="${REGISTRY_URL:+$REGISTRY_URL/}"
          VERSIONED_TAG="${PREFIX}${IMAGE_REPO}:${IMAGE_TAG}"
          LATEST_TAG="${PREFIX}${IMAGE_REPO}:${IMAGE_LATEST}"
          docker tag "$SRC_IMAGE" "$VERSIONED_TAG"
          docker tag "$SRC_IMAGE" "$LATEST_TAG"
        '''
      }
    }

    stage('Démarrage des services (compose up)') {
      steps {
        sh '''
          docker compose up -d
          docker compose ps
        '''
      }
    }

    stage('Tests') {
      steps {
        script {
          if (fileExists('package.json')) {
            sh 'docker compose exec -T app npm test || true'
          } else if (fileExists('pytest.ini')) {
            sh 'docker compose exec -T app pytest || true'
          } else if (fileExists('pom.xml')) {
            sh 'docker compose exec -T app mvn -q -DskipTests=false test || true'
          } else {
            echo 'Aucun test détecté'
          }
        }
      }
    }

    stage('Login registry') {
      when { expression { return env.REGISTRY_CRED?.trim() } }
      steps {
        withCredentials([usernamePassword(credentialsId: env.REGISTRY_CRED, usernameVariable: 'REG_USER', passwordVariable: 'REG_PASS')]) {
          sh '''
            if [ -n "${REGISTRY_URL}" ]; then
              echo "$REG_PASS" | docker login "$REGISTRY_URL" -u "$REG_USER" --password-stdin
            else
              echo "$REG_PASS" | docker login -u "$REG_USER" --password-stdin
            fi
          '''
        }
      }
    }

    stage('Push image') {
      when { allOf { branch 'main'; expression { return env.REGISTRY_CRED?.trim() } } }
      steps {
        sh '''
          PREFIX="${REGISTRY_URL:+$REGISTRY_URL/}"
          VERSIONED_TAG="${PREFIX}${IMAGE_REPO}:${IMAGE_TAG}"
          LATEST_TAG="${PREFIX}${IMAGE_REPO}:${IMAGE_LATEST}"
          docker push "$VERSIONED_TAG"
          docker push "$LATEST_TAG"
        '''
      }
    }
  }

  post {
    always {
      sh 'docker compose down --remove-orphans || true'
      sh 'rm -rf node_modules/.cache || true'
      sh 'docker image prune -af || true'
    }
    success {
      script {
        try {
          slackSend(color: 'good', message: "Déploiement réussi : ${env.JOB_NAME} #${env.BUILD_NUMBER}", tokenCredentialId: 'slack-token')
        } catch (Exception e) { echo "Slack non envoyé" }
      }
    }
    failure {
      script {
        try {
          slackSend(color: 'danger', message: "Échec du déploiement : ${env.JOB_NAME} #${env.BUILD_NUMBER}", tokenCredentialId: 'slack-token')
        } catch (Exception e) { echo "Slack non envoyé" }
      }
    }
  }
}
