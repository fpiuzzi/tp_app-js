pipeline {
  agent any

  tools {
    nodejs 'node18'
  }

  parameters {
    booleanParam(name: 'SLACK_TEST', defaultValue: false, description: 'Envoyer un message de test Slack pendant le build')
  }

  environment {
    APP_NAME              = 'mon-app-js'
    CONTAINER_NAME        = 'mon-app-js-container'
    STAGING_PORT          = '3001'
    PRODUCTION_PORT       = '3000'

    // >>> Push en local : on cible le registre local non-authentifié
    REGISTRY_URL          = '127.0.0.1:5000'      // registre local en HTTP
    IMAGE_REPO            = 'monuser/mon-app-js'  // namespace/répo côté registre local
    REGISTRY_CRED         = ''                    // pas de login pour le registre local

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
          if (env.GIT_SHORT) {
            env.IMAGE_TAG = env.BUILD_NUMBER ? "${env.GIT_SHORT}-${env.BUILD_NUMBER}" : env.GIT_SHORT
          } else {
            def ts = new Date().format('yyyyMMddHHmmss', TimeZone.getTimeZone('UTC'))
            env.IMAGE_TAG = env.BUILD_NUMBER ?: ts
          }
          echo "IMAGE_TAG (après checkout) = ${env.IMAGE_TAG}"
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
          set -eu
          docker compose build --pull

          SRC_IMAGE="${APP_NAME}"

          # Fallback si IMAGE_TAG est vide/null/-
          if [ -z "${IMAGE_TAG:-}" ] || [ "${IMAGE_TAG:-}" = "null" ] || [ "${IMAGE_TAG:-}" = "-" ]; then
            GIT_SHORT_FALLBACK="$(git rev-parse --short HEAD 2>/dev/null || true)"
            TS="$(date -u +%Y%m%d%H%M%S)"
            if [ -n "${BUILD_NUMBER:-}" ] && [ -n "$GIT_SHORT_FALLBACK" ]; then
              IMAGE_TAG="${GIT_SHORT_FALLBACK}-${BUILD_NUMBER}"
            elif [ -n "${BUILD_NUMBER:-}" ]; then
              IMAGE_TAG="${BUILD_NUMBER}"
            else
              IMAGE_TAG="${TS}"
            fi
          fi

          echo "DEBUG -> IMAGE_TAG=${IMAGE_TAG}"
          PREFIX="${REGISTRY_URL:+$REGISTRY_URL/}"
          VERSIONED_TAG="${PREFIX}${IMAGE_REPO}:${IMAGE_TAG}"
          LATEST_TAG="${PREFIX}${IMAGE_REPO}:${IMAGE_LATEST}"

          docker tag "${SRC_IMAGE}" "${VERSIONED_TAG}"
          docker tag "${SRC_IMAGE}" "${LATEST_TAG}"
        '''
      }
    }

    // Démarre un registry local en HTTP sur 127.0.0.1:5000 s'il n'existe pas
    stage('Ensure local registry') {
      steps {
        sh '''
          set -eu
          if ! docker ps --format '{{.Names}}' | grep -q '^registry$'; then
            if docker ps -a --format '{{.Names}}' | grep -q '^registry$'; then
              docker start registry
            else
              docker run -d --restart=always --name registry -p 5000:5000 \
                -v registry-data:/var/lib/registry registry:2
            fi
          fi
          docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | sed -n '1p;/^registry\\>/p'
        '''
      }
    }

    stage('Démarrage des services (compose up)') {
      steps {
        sh '''
          set -eu
          docker compose up -d
          docker compose ps
        '''
      }
    }

    stage('Tests') {
      steps {
        script {
          sh '''
            echo "== Diagnostics avant test =="
            docker compose ps || true
            docker compose logs --no-color --tail=200 app || true
          '''
          if (fileExists('package.json')) {
            sh 'docker compose run --rm app npm test || true'
          } else if (fileExists('pytest.ini')) {
            sh 'docker compose run --rm app pytest || true'
          } else if (fileExists('pom.xml')) {
            sh 'docker compose run --rm app mvn -q -DskipTests=false test || true'
          } else {
            echo 'Aucun test détecté'
          }
        }
      }
    }

    // Pas de login (REGISTRY_CRED vide). On push quand même (registre local sans auth).
    stage('Push image (local)') {
      when { branch 'master' }
      steps {
        sh '''
          set -eu
          PREFIX="${REGISTRY_URL:+$REGISTRY_URL/}"
          VERSIONED_TAG="${PREFIX}${IMAGE_REPO}:${IMAGE_TAG}"
          LATEST_TAG="${PREFIX}${IMAGE_REPO}:${IMAGE_LATEST}"
          docker push "${VERSIONED_TAG}"
          docker push "${LATEST_TAG}"

          echo "== Tags présents dans le registre local =="
          curl -s http://127.0.0.1:5000/v2/_catalog || true
          curl -s http://127.0.0.1:5000/v2/${IMAGE_REPO}/tags/list || true
        '''
      }
    }

    stage('Test Slack (temp)') {
      when { expression { return params.SLACK_TEST } }
      steps {
        script {
          try {
            slackSend(
              teamDomain: 'devopsipi',
              channel: '#tous-devopsipi',
              botUser: true,
              color: '#439FE0',
              message: "Ping de test Jenkins (${env.JOB_NAME} #${env.BUILD_NUMBER})",
              tokenCredentialId: 'slack-token'
            )
          } catch (e) {
            echo "Slack non envoyé: ${e.message}"
          }
        }
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
          slackSend(
            teamDomain: 'devopsipi',
            channel: '#tous-devopsipi',
            botUser: true,
            color: 'good',
            message: "Déploiement réussi : ${env.JOB_NAME} #${env.BUILD_NUMBER}",
            tokenCredentialId: 'slack-token'
          )
        } catch (Exception e) { echo "Slack non envoyé: ${e.message}" }
      }
    }
    failure {
      script {
        try {
          slackSend(
            teamDomain: 'devopsipi',
            channel: '#tous-devopsipi',
            botUser: true,
            color: 'danger',
            message: "Échec du déploiement : ${env.JOB_NAME} #${env.BUILD_NUMBER}",
            tokenCredentialId: 'slack-token'
          )
        } catch (Exception e) { echo "Slack non envoyé: ${e.message}" }
      }
    }
  }
}
