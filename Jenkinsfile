pipeline {
  agent any

  triggers {
    pollSCM('H/5 * * * *')
  }

  options {
    buildDiscarder(logRotator(numToKeepStr: '20'))
    disableConcurrentBuilds()
    skipDefaultCheckout(true)
    timestamps()
    timeout(time: 45, unit: 'MINUTES')
  }

  parameters {
    string(name: 'AWS_REGION', defaultValue: 'us-east-1', description: 'AWS Region containing ECR and ECS.')
    string(name: 'WEB_ECR_REPOSITORY', defaultValue: '', description: 'Full ECR repository URL for the web service.')
    string(name: 'API_ECR_REPOSITORY', defaultValue: '', description: 'Full ECR repository URL for the API service.')
    string(name: 'ECS_CLUSTER', defaultValue: 'ecs-release-console-prod', description: 'ECS cluster name.')
    string(name: 'WEB_ECS_SERVICE', defaultValue: 'ecs-release-console-prod-web', description: 'Web ECS service name.')
    string(name: 'API_ECS_SERVICE', defaultValue: 'ecs-release-console-prod-api', description: 'API ECS service name.')
    string(name: 'APPLICATION_URL', defaultValue: '', description: 'ALB application URL used for smoke tests.')
    string(name: 'APP_ENVIRONMENT', defaultValue: 'prod', description: 'Environment reported by the API.')
    string(name: 'APP_VERSION', defaultValue: '0.1.0', description: 'Human-readable release version.')
  }

  environment {
    TRIVY_IMAGE = 'aquasec/trivy:0.66.0'
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
        script {
          env.COMMIT_SHA = sh(
            script: 'git rev-parse HEAD',
            returnStdout: true
          ).trim()
          env.IMAGE_TAG = "sha-${env.COMMIT_SHA}"
          env.WEB_IMAGE_URI = "${params.WEB_ECR_REPOSITORY}:${env.IMAGE_TAG}"
          env.API_IMAGE_URI = "${params.API_ECR_REPOSITORY}:${env.IMAGE_TAG}"
        }
      }
    }

    stage('Validate configuration') {
      steps {
        sh '''
          set -Eeuo pipefail
          test -n "${WEB_ECR_REPOSITORY}"
          test -n "${API_ECR_REPOSITORY}"
          test -n "${APPLICATION_URL}"
          aws sts get-caller-identity
          aws ecs describe-services \
            --region "${AWS_REGION}" \
            --cluster "${ECS_CLUSTER}" \
            --services "${WEB_ECS_SERVICE}" "${API_ECS_SERVICE}" \
            --query 'length(services)' \
            --output text | grep -qx '2'
        '''
      }
    }

    stage('Application tests') {
      steps {
        sh '''
          set -Eeuo pipefail
          npm ci --prefix apps/api
          npm ci --prefix apps/web
          npm run validate
        '''
      }
    }

    stage('Build images') {
      steps {
        sh '''
          set -Eeuo pipefail
          docker build \
            --label "org.opencontainers.image.revision=${COMMIT_SHA}" \
            --tag "${WEB_IMAGE_URI}" \
            apps/web
          docker build \
            --label "org.opencontainers.image.revision=${COMMIT_SHA}" \
            --tag "${API_IMAGE_URI}" \
            apps/api
        '''
      }
    }

    stage('Scan images') {
      steps {
        sh '''
          set -Eeuo pipefail
          docker pull "${TRIVY_IMAGE}"
          docker run --rm \
            -v /var/run/docker.sock:/var/run/docker.sock \
            "${TRIVY_IMAGE}" image \
            --exit-code 1 \
            --ignore-unfixed \
            --severity CRITICAL \
            "${WEB_IMAGE_URI}"
          docker run --rm \
            -v /var/run/docker.sock:/var/run/docker.sock \
            "${TRIVY_IMAGE}" image \
            --exit-code 1 \
            --ignore-unfixed \
            --severity CRITICAL \
            "${API_IMAGE_URI}"
        '''
      }
    }

    stage('Push immutable images') {
      steps {
        sh '''
          set -Eeuo pipefail
          SKIP_BUILD=true scripts/build-and-push.sh \
            "${AWS_REGION}" \
            "${WEB_ECR_REPOSITORY}" \
            "${API_ECR_REPOSITORY}" \
            "${COMMIT_SHA}"
        '''
      }
    }

    stage('Deploy and verify') {
      steps {
        sh '''
          set -Eeuo pipefail

          previous_api=$(
            aws ecs describe-services \
              --region "${AWS_REGION}" \
              --cluster "${ECS_CLUSTER}" \
              --services "${API_ECS_SERVICE}" \
              --query 'services[0].taskDefinition' \
              --output text
          )
          previous_web=$(
            aws ecs describe-services \
              --region "${AWS_REGION}" \
              --cluster "${ECS_CLUSTER}" \
              --services "${WEB_ECS_SERVICE}" \
              --query 'services[0].taskDefinition' \
              --output text
          )

          rollback_release() {
            printf 'Release failed; restoring both previous task definitions.\n' >&2
            scripts/rollback-service.sh \
              "${AWS_REGION}" "${ECS_CLUSTER}" "${API_ECS_SERVICE}" "${previous_api}" || true
            scripts/rollback-service.sh \
              "${AWS_REGION}" "${ECS_CLUSTER}" "${WEB_ECS_SERVICE}" "${previous_web}" || true
          }
          trap rollback_release ERR

          scripts/deploy-service.sh \
            "${AWS_REGION}" \
            "${ECS_CLUSTER}" \
            "${API_ECS_SERVICE}" \
            api \
            "${API_IMAGE_URI}" \
            "${APP_ENVIRONMENT}" \
            "${APP_VERSION}" \
            "${COMMIT_SHA}"

          scripts/deploy-service.sh \
            "${AWS_REGION}" \
            "${ECS_CLUSTER}" \
            "${WEB_ECS_SERVICE}" \
            web \
            "${WEB_IMAGE_URI}" \
            "${APP_ENVIRONMENT}" \
            "${APP_VERSION}" \
            "${COMMIT_SHA}"

          aws ecs wait services-stable \
            --region "${AWS_REGION}" \
            --cluster "${ECS_CLUSTER}" \
            --services "${API_ECS_SERVICE}" "${WEB_ECS_SERVICE}"

          scripts/smoke-test.sh "${APPLICATION_URL}" "${COMMIT_SHA}"
          trap - ERR
        '''
      }
    }
  }

  post {
    always {
      sh 'docker image prune --force || true'
      deleteDir()
    }
  }
}
