pipeline {
  agent any

  parameters {
    booleanParam(name: 'SLACK_TEST', defaultValue: false, description: 'Envoyer un message de test Slack pendant le build')
  }

  options { timestamps() }

  environment {
    APP_NAME         = 'mon-app-js'
    IMAGE_REPO       = 'monuser/mon-app-js'
    LOCAL_REGISTRY   = '127.0.0.1:5000'

    // Slack
    SLACK_TEAM       = 'devopsipi'
    SLACK_CHANNEL    = '#tous-devopsipi'
    SLACK_TOKEN_CRED = 'slack-token'
  }

  stages {
    stage('Build image (compose)') {
      steps {
        sh '''
          set -eu

          docker compose build --pull

          GIT_SHORT=$(git rev-parse --short HEAD)
          BUILD_NO=${BUILD_NUMBER}
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
          slackSend(
            teamDomain: env.SLACK_TEAM,
            channel: env.SLACK_CHANNEL,
            color: 'good',
            message: "Test Slack depuis Jenkins (${env.JOB_NAME} #${env.BUILD_NUMBER})",
            tokenCredentialId: env.SLACK_TOKEN_CRED,
            botUser: true
          )
        }
      }
    }

    stage('Ensure local registry') {
      steps {
        sh '''
          set -eu
          if ! docker ps --format '{{.Names}}' | grep -q '^registry$'; then
            if docker ps -a --format '{{.Names}}' | grep -q '^registry$'; then
              docker start registry
            else
              docker run -d --restart=always --name registry -p 5000:5000 -v registry-data:/var/lib/registry registry:2
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

          GIT_SHORT=$(git rev-parse --short HEAD)
          BUILD_NO=${BUILD_NUMBER}
          IMAGE_TAG="${GIT_SHORT}-${BUILD_NO}"

          PREFIX="${LOCAL_REGISTRY}/"
          VERSIONED_TAG="${PREFIX}${IMAGE_REPO}:${IMAGE_TAG}"
          LATEST_TAG="${PREFIX}${IMAGE_REPO}:latest"

          echo "Pushing -> $VERSIONED_TAG & $LATEST_TAG"
          docker push "$VERSIONED_TAG"
          docker push "$LATEST_TAG"

          echo "Verification (_catalog):"
          docker run --rm --network=container:registry curlimages/curl:8.10.1 \
            -fsS "http://127.0.0.1:5000/v2/_catalog" || true

          echo "Verification (tags):"
          docker run --rm --network=container:registry curlimages/curl:8.10.1 \
            -fsS "http://127.0.0.1:5000/v2/${IMAGE_REPO}/tags/list" || true
        '''
      }
    }
  }

  post {
    success {
      script {
        slackSend(
          teamDomain: env.SLACK_TEAM,
          channel: env.SLACK_CHANNEL,
          color: 'good',
          message: "Succès: image poussée dans le registry local (${env.JOB_NAME} #${env.BUILD_NUMBER})",
          tokenCredentialId: env.SLACK_TOKEN_CRED,
          botUser: true
        )
      }
    }
    failure {
      script {
        slackSend(
          teamDomain: env.SLACK_TEAM,
          channel: env.SLACK_CHANNEL,
          color: 'danger',
          message: "Échec: voir les logs Jenkins (${env.JOB_NAME} #${env.BUILD_NUMBER})",
          tokenCredentialId: env.SLACK_TOKEN_CRED,
          botUser: true
        )
      }
    }
    always {
      sh 'docker image prune -af || true'
    }
  }
}
