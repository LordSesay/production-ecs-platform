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
    // SCM-polled builds always run with these defaults, so every value must
    // either have a working default or be derivable from NAME_PREFIX.
    string(name: 'AWS_REGION', defaultValue: 'us-east-1', description: 'AWS Region containing ECR and ECS.')
    string(name: 'NAME_PREFIX', defaultValue: 'ecs-release-console-prod', description: 'Foundation name_prefix output (<project_name>-<environment>).')
    string(name: 'WEB_ECR_REPOSITORY', defaultValue: '', description: 'Optional override. Empty derives <account>.dkr.ecr.<region>.amazonaws.com/<NAME_PREFIX>-web.')
    string(name: 'API_ECR_REPOSITORY', defaultValue: '', description: 'Optional override. Empty derives <account>.dkr.ecr.<region>.amazonaws.com/<NAME_PREFIX>-api.')
    string(name: 'ECS_CLUSTER', defaultValue: 'ecs-release-console-prod', description: 'ECS cluster name.')
    string(name: 'WEB_ECS_SERVICE', defaultValue: 'ecs-release-console-prod-web', description: 'Web ECS service name.')
    string(name: 'API_ECS_SERVICE', defaultValue: 'ecs-release-console-prod-api', description: 'API ECS service name.')
    string(name: 'APPLICATION_URL', defaultValue: '', description: 'Optional override. Empty derives http://<DNS name of NAME_PREFIX-alb>. Set this when HTTPS and a custom domain are configured.')
    string(name: 'APP_ENVIRONMENT', defaultValue: 'prod', description: 'Environment reported by the API.')
    string(name: 'APP_VERSION', defaultValue: '0.1.0', description: 'Human-readable release version.')
  }

  environment {
    // Keep NODE_IMAGE aligned with the build stage in apps/*/Dockerfile.
    // The controller has no Node.js installed; validation runs in this image.
    NODE_IMAGE  = 'node:24.14.0-alpine3.23'
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
        }
      }
    }

    stage('Resolve release targets') {
      steps {
        script {
          def accountId = sh(
            script: 'aws sts get-caller-identity --query Account --output text',
            returnStdout: true
          ).trim()
          def registry = "${accountId}.dkr.ecr.${params.AWS_REGION}.amazonaws.com"

          env.RELEASE_WEB_REPOSITORY = params.WEB_ECR_REPOSITORY?.trim() ?: "${registry}/${params.NAME_PREFIX}-web"
          env.RELEASE_API_REPOSITORY = params.API_ECR_REPOSITORY?.trim() ?: "${registry}/${params.NAME_PREFIX}-api"

          if (params.APPLICATION_URL?.trim()) {
            env.RELEASE_APPLICATION_URL = params.APPLICATION_URL.trim()
          } else {
            def albDnsName = sh(
              script: '''aws elbv2 describe-load-balancers \
                --region "${AWS_REGION}" \
                --names "${NAME_PREFIX}-alb" \
                --query 'LoadBalancers[0].DNSName' \
                --output text''',
              returnStdout: true
            ).trim()
            env.RELEASE_APPLICATION_URL = "http://${albDnsName}"
          }

          env.WEB_IMAGE_URI = "${env.RELEASE_WEB_REPOSITORY}:${env.IMAGE_TAG}"
          env.API_IMAGE_URI = "${env.RELEASE_API_REPOSITORY}:${env.IMAGE_TAG}"

          echo "Web image: ${env.WEB_IMAGE_URI}"
          echo "API image: ${env.API_IMAGE_URI}"
          echo "Smoke-test URL: ${env.RELEASE_APPLICATION_URL}"
        }
      }
    }

    stage('Validate configuration') {
      steps {
        sh '''
          set -Eeuo pipefail
          test -n "${RELEASE_WEB_REPOSITORY}"
          test -n "${RELEASE_API_REPOSITORY}"
          test -n "${RELEASE_APPLICATION_URL}"
          test "${RELEASE_APPLICATION_URL}" != "http://None"
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
        // Run as the Jenkins user so deleteDir() can remove node_modules later.
        sh '''
          set -Eeuo pipefail
          docker run --rm \
            --user "$(id -u):$(id -g)" \
            --env HOME=/tmp \
            --env npm_config_cache=/tmp/.npm \
            --volume "${WORKSPACE}:/workspace" \
            --workdir /workspace \
            "${NODE_IMAGE}" \
            sh -c 'npm run install:all && npm run validate'
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
            "${RELEASE_WEB_REPOSITORY}" \
            "${RELEASE_API_REPOSITORY}" \
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

          scripts/smoke-test.sh "${RELEASE_APPLICATION_URL}" "${COMMIT_SHA}"
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
