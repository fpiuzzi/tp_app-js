pipeline {
  agent any
  options { timestamps() }

  environment {
    REGISTRY_URL    = '127.0.0.1:5000'
    IMAGE_REPO      = 'monuser/mon-app-js'
    PLATFORMS       = 'linux/amd64,linux/arm64'
    DOCKER_BUILDKIT = '1'
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Compute image tag') {
      steps {
        script {
          def shortSha = sh(returnStdout: true, script: "git rev-parse --short=8 HEAD").trim()
          env.IMAGE_TAG = "${shortSha}-${env.BUILD_NUMBER}"
          echo "IMAGE_TAG=${env.IMAGE_TAG}"
        }
      }
    }

    stage('Ensure local registry (with HTTP secret)') {
      steps {
        withCredentials([string(credentialsId: 'registry-http-secret', variable: 'REGISTRY_HTTP_SECRET')]) {
          sh '''
            set -euo pipefail
            # Démarre/replace le registry avec un secret stable
            if ! docker ps --format '{{.Names}}' | grep -qx registry; then
              docker rm -f registry >/dev/null 2>&1 || true
              docker run -d --restart=always --name registry -p 5000:5000 \
                -v registry-data:/var/lib/registry \
                -e REGISTRY_HTTP_SECRET="${REGISTRY_HTTP_SECRET:-changeme-unsafe}" \
                registry:2
            else
              echo "Registry déjà en marche."
            fi

            # Sanity check
            docker run --rm --network=host curlimages/curl:8.10.1 -fsS http://127.0.0.1:5000/v2/ > /dev/null
          '''
        }
      }
    }

    stage('Prepare buildx builder') {
      steps {
        sh '''
          set -euo pipefail
          docker buildx inspect ci-builder >/dev/null 2>&1 || docker buildx create --name ci-builder --use
          docker buildx use ci-builder
          docker buildx inspect --bootstrap
        '''
      }
    }

    stage('Build & Push') {
      steps {
        sh '''
          set -euo pipefail
          IMAGE="${REGISTRY_URL}/${IMAGE_REPO}"

          echo "Building ${IMAGE}:${IMAGE_TAG} (+ latest) for ${PLATFORMS}"
          docker buildx build \
            --platform "${PLATFORMS}" \
            -t "${IMAGE}:${IMAGE_TAG}" \
            -t "${IMAGE}:latest" \
            --push \
            .

          echo "Build & push terminé."
        '''
      }
    }

    stage('Verify push (tags + manifests)') {
      steps {
        sh '''
          set -euo pipefail
          REPO="${IMAGE_REPO}"
          BASE="http://127.0.0.1:5000/v2/${REPO}"
          RCURL="docker run --rm --network=host curlimages/curl:8.10.1 -fsS"

          echo "Vérification de la présence du tag ${IMAGE_TAG} dans /tags/list ..."
          ok=false
          for i in $(seq 1 15); do
            if $RCURL "${BASE}/tags/list" | tee /dev/stderr | grep -q "\"${IMAGE_TAG}\""; then
              ok=true; break
            fi
            sleep 1
          done
          $ok || { echo "Tag ${IMAGE_TAG} absent après retries" >&2; exit 1; }

          echo "HEAD manifest ${IMAGE_TAG} + latest ..."
          for tag in "${IMAGE_TAG}" "latest"; do
            ok=false
            for i in $(seq 1 15); do
              code=$($RCURL -o /dev/null -w "%{http_code}" -I "${BASE}/manifests/${tag}" || true)
              if [ "$code" = "200" ]; then ok=true; break; fi
              sleep 1
            done
            $ok || { echo "Manifest ${tag} indisponible après retries" >&2; exit 1; }
            echo "Manifest ${tag} disponible ✅"
          done
        '''
      }
    }
  }

  post {
    success {
      echo "Push OK: ${env.REGISTRY_URL}/${env.IMAGE_REPO}:${env.IMAGE_TAG} et :latest"
    }
    failure {
      echo "Échec du push/verify – voir les logs ci-dessus."
    }
  }
}
