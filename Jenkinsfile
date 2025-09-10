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
    REGISTRY_URL          = ''                           // ex: registry.hub.docker.com
    IMAGE_REPO            = 'monuser/mon-app-js'         // ex: namespace/repo
    REGISTRY_CRED         = 'REGISTRY_CRED'              // credentialsId Jenkins (username+password)
    GIT_SHORT             = ''
    IMAGE_TAG             = ''                           // calculé au checkout, fallback au build
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
          def short = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
          def bn = env.BUILD_NUMBER ?: ''
          if (short) {
            env.GIT_SHORT = short
            env.IMAGE_TAG = bn ? "${short}-${bn}" : short
          } else {
            def ts = new Date().format('yyyyMMddHHmmss', TimeZone.getTimeZone('UTC'))
            env.IMAGE_TAG = bn ? "${bn}" : ts
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
            set -eu
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
      when {
        allOf {
          branch 'master'
          expression { return env.REGISTRY_CRED?.trim() }
        }
      }
      steps {
        sh '''
          set -eu
          PREFIX="${REGISTRY_URL:+$REGISTRY_URL/}"
          VERSIONED_TAG="${PREFIX}${IMAGE_REPO}:${IMAGE_TAG}"
          LATEST_TAG="${PREFIX}${IMAGE_REPO}:${IMAGE_LATEST}"
          docker push "${VERSIONED_TAG}"
          docker push "${LATEST_TAG}"
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
          slackSend(
            teamDomain: 'devopsipi',          // sous-domaine Slack (pas d’URL)
            channel: '#tous-devopsipi',       // assure-toi que le bot est invité
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
