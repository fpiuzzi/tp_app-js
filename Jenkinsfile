pipeline {
  agent any

  tools { nodejs 'node18' }

  parameters {
    booleanParam(
      name: 'SLACK_TEST',
      defaultValue: false,
      description: 'Envoyer un message de test Slack pendant le build'
    )
  }

  environment {
    // --- Docker / Registry local ---
    APP_NAME     = 'mon-app-js'                 // doit matcher l'image construite par docker-compose
    IMAGE_REPO   = 'monuser/mon-app-js'         // nom du repo dans le registre
    REGISTRY_URL = '127.0.0.1:5000'             // registre local
    IMAGE_LATEST = 'latest'

    // --- Slack ---
    SLACK_TEAM   = 'devopsipi'                  // workspace (sans .slack.com)
    SLACK_CHAN   = '#tous-devopsipi'            // salon Slack
    SLACK_CRED   = 'slack-token'                // Jenkins credential (Secret text xoxb-...)
  }

  options {
    timestamps()
    skipDefaultCheckout(true)
  }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Build image (compose)') {
      steps {
        sh '''
          set -eu
          docker compose build --pull

          # Tag versionné : <commit>-<buildNumber>
          GIT_SHORT="$(git rev-parse --short HEAD)"
          BUILD_NO="${BUILD_NUMBER:-0}"
          IMAGE_TAG="${GIT_SHORT}-${BUILD_NO}"

          SRC_IMAGE="${APP_NAME}"
          PREFIX="${REGISTRY_URL:+$REGISTRY_URL/}"
          VERSIONED_TAG="${PREFIX}${IMAGE_REPO}:${IMAGE_TAG}"
          LATEST_TAG="${PREFIX}${IMAGE_REPO}:${IMAGE_LATEST}"

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
              teamDomain: env.SLACK_TEAM,
              channel:    env.SLACK_CHAN,
              color:      'good',
              botUser:    true,
              message:    "Slack test message (build en cours) : ${env.JOB_NAME} #${env.BUILD_NUMBER}",
              tokenCredentialId: env.SLACK_CRED
            )
          } catch (Exception e) {
            echo "Slack test non envoyé : ${e.getMessage()}"
          }
        }
      }
    }

    stage('Ensure local registry') {
      steps {
        sh '''
          set -eu
          # Démarre un registre local (port 5000) si absent
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

          PREFIX="${REGISTRY_URL:+$REGISTRY_URL/}"
          VERSIONED_TAG="${PREFIX}${IMAGE_REPO}:${IMAGE_TAG}"
          LATEST_TAG="${PREFIX}${IMAGE_REPO}:${IMAGE_LATEST}"

          echo "Pushing -> ${VERSIONED_TAG} & ${LATEST_TAG}"
          docker push "$VERSIONED_TAG"
          docker push "$LATEST_TAG"

          echo "Verification:"
          curl -s http://${REGISTRY_URL}/v2/_catalog || true
          echo
          curl -s http://${IMAGE_REPO/@/\\@} >/dev/null 2>&1 || true
          curl -s http://${REGISTRY_URL}/v2/${IMAGE_REPO}/tags/list || true
          echo
        '''
      }
    }
  }

  post {
    success {
      script {
        try {
          slackSend(
            teamDomain: env.SLACK_TEAM,
            channel:    env.SLACK_CHAN,
            color:      'good',
            botUser:    true,
            message:    "Build and push successful: ${env.JOB_NAME} #${env.BUILD_NUMBER} -> ${env.REGISTRY_URL}/${env.IMAGE_REPO}:${env.IMAGE_LATEST}",
            tokenCredentialId: env.SLACK_CRED
          )
        } catch (Exception e) {
          echo "Slack non envoyé (success) : ${e.getMessage()}"
        }
      }
    }
    failure {
      script {
        try {
          slackSend(
            teamDomain: env.SLACK_TEAM,
            channel:    env.SLACK_CHAN,
            color:      'danger',
            botUser:    true,
            message:    "Pipeline failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
            tokenCredentialId: env.SLACK_CRED
          )
        } catch (Exception e) {
          echo "Slack non envoyé (failure) : ${e.getMessage()}"
        }
      }
    }
    always {
      sh 'docker image prune -af || true'
    }
  }
}
