pipeline {
  agent any

  environment {
    REGISTRY = "naresh240"
    TF_DIR = "infra"
  }

  stages {
    stage('Checkout') {
      steps {
        git branch: 'main', 
            url: 'https://github.com/Naresh240/employee-management-app-with-blue-green-strategy.git'
      }
    }

    stage('Build & Push Images') {
      steps {
        script {
          def version = "v${env.BUILD_NUMBER}"
          env.APP_VERSION = version

          sh """
            docker build -t $REGISTRY/backend-app:${version} backend/
            docker build -t $REGISTRY/frontend-app:${version} frontend/
            docker push $REGISTRY/backend-app:${version}
            docker push $REGISTRY/frontend-app:${version}
          """
        }
      }
    }

    stage('Terraform Init & Apply') {
      steps {
        dir("${TF_DIR}") {
          sh """
            terraform init
            terraform apply -auto-approve
          """
        }
      }
    }

    stage('Get Manager IP') {
      steps {
        script {
          env.MANAGER_IP = sh(
            script: "cd ${TF_DIR} && terraform output -raw manager_ip",
            returnStdout: true
          ).trim()
          echo "Manager IP: ${env.MANAGER_IP}"
        }
      }
    }

    stage('Blue-Green Deployment') {
      steps {
        sh """
          bash scripts/deploy_blue_green.sh ${MANAGER_IP} ${APP_VERSION}
        """
      }
    }
  }

  post {
    failure {
      echo "Deployment failed. Please check logs."
    }
  }
}
