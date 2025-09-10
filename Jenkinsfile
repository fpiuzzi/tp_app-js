pipeline {
  agent any

  tools {
    nodejs 'node18'
  }

  parameters {
    booleanParam(name: 'SLACK_TEST', defaultValue: false, description: 'Envoyer un message de test Slack pendant le build')
  }

  environment {
    APP_NAME             = 'mon-app-js'
    IMAGE_REPO           = 'monuser/mon-app-js'
    LOCAL_REGISTRY       = '127.0.0.1:5000'
    COMPOSE_PROJECT_NAME = "${env.JOB_NAME}-${env.BUILD_NUMBER}"
  }

  options {
    timestamps()
    skipDefaultCheckout(true)
  }

  stages {

    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Build image (compose)') {
      steps {
        sh '''
          set -eu
          docker compose build --pull

          GIT_SHORT="$(git rev-parse --short HEAD)"
          BUILD_NO="${BUILD_NUMBER:-0}"
          IMAGE_TAG="${GIT_SHORT}-${BUILD_NO}"

          SRC_IMAGE="${APP_NAME}"
          PREFIX="${LOCAL_REGISTRY}/"
          VERSIONED_TAG="${PREFIX}${IMAGE_REPO}:${IMAGE_TAG}"
          LATEST_TAG="${PREFIX}${IMAGE_REPO}:latest"

          docker tag "$SRC_IMAGE" "$VERSIONED_TAG"
          docker tag "$SRC_IMAGE" "$LATEST_TAG"

          echo "Tagged:"
          echo " - $VERSIONED_TAG"
          echo " - $LATEST_TAG"
        '''
      }
    }

    stage('Slack test (optionnel)') {
      when { expression { return params.SLACK_TEST } }
      steps {
        script {
          try {
            slackSend(
              teamDomain: 'devopsipi',
              channel: '#tous-devopsipi',
              color: 'good',
              botUser: true,
              tokenCredentialId: 'slack-token',
              message: "Test Slack OK depuis ${env.JOB_NAME} #${env.BUILD_NUMBER}"
            )
          } catch (e) {
            echo "Slack test non envoyé: ${e}"
          }
        }
      }
    }

    stage('Ensure local registry') {
      steps {
        sh '''
          set -eu
          if ! docker ps --format '{{.Names}}' | grep -q '^registry$'; then
            if ! docker ps -a --format '{{.Names}}' | grep -q '^registry$'; then
              docker run -d --restart=always --name registry -p 5000:5000 -v registry-data:/var/lib/registry registry:2
            else
              docker start registry
            fi
          fi
          echo "Registry status:"
          docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | sed -n '1p;/^registry\\>/p'
        '''
      }
    }

    stage('Push image (local)') {
      steps {
        sh '''
          set -eu
          GIT_SHORT="$(git rev-parse --short HEAD)"
          BUILD_NO="${BUILD_NUMBER:-0}"
          IMAGE_TAG="${GIT_SHORT}-${BUILD_NO}"

          PREFIX="${LOCAL_REGISTRY}/"
          VERSIONED_TAG="${PREFIX}${IMAGE_REPO}:${IMAGE_TAG}"
          LATEST_TAG="${PREFIX}${IMAGE_REPO}:latest"

          echo "Pushing -> $VERSIONED_TAG & $LATEST_TAG"
          docker push "$VERSIONED_TAG"
          docker push "$LATEST_TAG"

          echo "Verification (_catalog):"
          CATALOG="$(curl -s http://${LOCAL_REGISTRY}/v2/_catalog || true)"
          echo "$CATALOG"

          # Vérif simple sans bash-isms
          echo "$CATALOG" | grep -q "\"${IMAGE_REPO}\"" || echo "Repository non visible dans /v2/_catalog (peut prendre un court délai)."
        '''
      }
    }
  }

  post {
    success {
      script {
        try {
          slackSend(
            teamDomain: 'devopsipi',
            channel: '#tous-devopsipi',
            color: 'good',
            botUser: true,
            tokenCredentialId: 'slack-token',
            message: "SUCCESS : ${env.JOB_NAME} #${env.BUILD_NUMBER}"
          )
        } catch (e) { echo "Slack non envoyé (success): ${e}" }
      }
    }
    failure {
      script {
        try {
          slackSend(
            teamDomain: 'devopsipi',
            channel: '#tous-devopsipi',
            color: 'danger',
            botUser: true,
            tokenCredentialId: 'slack-token',
            message: "FAILURE : ${env.JOB_NAME} #${env.BUILD_NUMBER}"
          )
        } catch (e) { echo "Slack non envoyé (failure): ${e}" }
      }
    }
    always {
      // pas de compose down ici, on ne lance pas le service avec compose
      sh 'docker image prune -af || true'
    }
  }
}
