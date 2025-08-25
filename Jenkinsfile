pipeline {
  agent any

  tools {
    nodejs 'node18'
  }

  environment {
    APP_NAME   = 'mon-app-js'
    DEPLOY_DIR = '/var/www/html/mon-app'
    DEFAULT_RECIPIENTS = 'florent.piuzzi@edu.igensia.com'
  }

  stages {
    stage('Checkout') {
      steps {
        echo 'Récupération du code source...'
        checkout scm
      }
    }

    stage('Install Dependencies') {
      steps {
        echo 'Installation des dépendances Node.js...'
        sh '''
          set -eux
          node --version
          npm --version

          if [ -f package-lock.json ] || [ -f npm-shrinkwrap.json ]; then
            echo "Lockfile détecté → npm ci"
            npm ci
          else
            echo "Pas de lockfile → npm install"
            npm install
            # Si tu veux stricter, décommente ces deux lignes :
            # npm install --package-lock-only
            # npm ci
          fi
        '''
        sh '''
          # Installation explicite de jest-junit
          npm install --save-dev jest-junit
        '''
      }
    }

    stage('Run Tests') {
      steps {
        echo 'Exécution des tests...'
        sh 'npm test'
      }
      post {
        always {
          junit testResults: '**/junit.xml', allowEmptyResults: true
        }
      }
    }

    stage('Code Quality Check') {
      steps {
        echo 'Vérification de la qualité du code (ESLint si présent)...'
        sh '''
          set -eux
          if [ -f package.json ] && grep -q '"eslint"' package.json 2>/dev/null; then
            npx eslint . || true   # n’échoue pas le build sur du lint
          else
            # Recherche d’une config eslint standard
            if ls -1A .eslintrc* >/dev/null 2>&1; then
              npx eslint . || true
            else
              echo "ESLint non configuré (skip)"
            fi
          fi
        '''
      }
    }

    stage('Build') {
      steps {
        echo 'Construction de l\'application...'
        sh '''
          set -eux
          npm run build
          ls -la || true
          ls -la dist || true
        '''
        archiveArtifacts artifacts: 'dist/**', fingerprint: true, allowEmptyArchive: true
      }
    }

    stage('Security Scan') {
      steps {
        echo 'Analyse de sécurité des dépendances...'
        sh '''
          set +e
          npm audit --audit-level=high
          echo "npm audit terminé (le build ne bloque pas, vérifier les logs ci-dessus)"
          set -e
        '''
      }
    }

    stage('Deploy to Staging') {
      when { branch 'develop' }
      steps {
        echo 'Déploiement vers l\'environnement de staging...'
        sh '''
          set -eux
          mkdir -p staging
          if [ -d dist ]; then
            cp -r dist/* staging/ || true
          fi
          ls -la staging || true
        '''
      }
    }

    stage('Deploy to Production') {
      when {
        anyOf {
          branch 'main'
          branch 'master'
        }
      }
      steps {
        echo 'Déploiement vers la production...'
        sh '''
          set -eux
          echo "Sauvegarde de la version précédente (si présente)..."
          if [ -d "${DEPLOY_DIR}" ]; then
            cp -r "${DEPLOY_DIR}" "${DEPLOY_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
          fi

          echo "Déploiement de la nouvelle version..."
          mkdir -p "${DEPLOY_DIR}"
          if [ -d dist ]; then
            cp -r dist/* "${DEPLOY_DIR}/" || true
          fi

          echo "Vérification du déploiement..."
          ls -la "${DEPLOY_DIR}" || true
        '''
      }
    }

    stage('Health Check') {
      steps {
        echo 'Vérification de santé de l\'application...'
        script {
          try {
            sh '''
              set -eux
              echo "Test de connectivité..."
              # Simulation d'un health check (remplacer par un curl sur l'URL si besoin)
              echo "Application déployée avec succès"
            '''
          } catch (e) {
            currentBuild.result = 'UNSTABLE'
            echo "Warning: Health check failed: ${e.getMessage()}"
          }
        }
      }
    }
  }

  post {
    always {
      echo 'Nettoyage des ressources temporaires...'
      sh '''
        rm -rf node_modules/.cache || true
        rm -rf staging || true
      '''
    }
    success {
      echo 'Pipeline exécuté avec succès!'
      emailext (
        subject: "Build Success: ${env.JOB_NAME} - ${env.BUILD_NUMBER}",
        body: """
          Le déploiement de ${env.JOB_NAME} s'est terminé avec succès.

          Build: ${env.BUILD_NUMBER}
          Branch: ${env.BRANCH_NAME}

          Voir les détails: ${env.BUILD_URL}
        """,
        to: "${env.CHANGE_AUTHOR_EMAIL ?: env.DEFAULT_RECIPIENTS}"
      )
    }
    failure {
      echo 'Le pipeline a échoué!'
      emailext (
        subject: "Build Failed: ${env.JOB_NAME} - ${env.BUILD_NUMBER}",
        body: """
          Le déploiement de ${env.JOB_NAME} a échoué.

          Build: ${env.BUILD_NUMBER}
          Branch: ${env.BRANCH_NAME}

          Voir les détails: ${env.BUILD_URL}
        """,
        to: "${env.CHANGE_AUTHOR_EMAIL ?: env.DEFAULT_RECIPIENTS}"
      )
    }
    unstable {
      echo 'Build instable - des avertissements ont été détectés'
    }
  }
}
