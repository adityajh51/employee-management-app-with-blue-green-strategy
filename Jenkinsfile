pipeline {
  agent any

  environment {
    REGISTRY = "naresh240"
    TF_DIR   = "infra"
  }

  stages {
    stage('Checkout') {
      steps {
        git branch: 'main', 
            url: 'https://github.com/Naresh240/employee-management-app-with-blue-green-strategy.git'
      }
    }

    stage('Build Packages') {
      parallel {
        stage('Backend Build') {
          steps { dir('backend') { sh 'mvn clean package -DskipTests' } }
        }
        stage('Frontend Build') {
          steps { dir('frontend') { sh 'npm install' } }
        }
      }
    }

    stage('Build & Push Images') {
      steps {
        script {
          def version = "v${env.BUILD_NUMBER}"
          env.APP_VERSION = version
          withCredentials([usernamePassword(credentialsId: 'dockerhub_creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
            sh """
              echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin
              docker build -t $REGISTRY/backend-app:${version} backend/
              docker build -t $REGISTRY/frontend-app:${version} frontend/
              docker push $REGISTRY/backend-app:${version}
              docker push $REGISTRY/frontend-app:${version}
              docker logout
            """
          }
        }
      }
    }

    stage('Terraform Init & Apply') {
      steps {
        sshagent(['swarm_key']) {
          dir("${TF_DIR}") {
            sh """
              terraform init
              terraform apply -auto-approve
            """
          }
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
        sshagent(['swarm_key']) {
          sh "bash scripts/deploy_blue_green.sh ${MANAGER_IP} ${APP_VERSION}"
        }
      }
    }
  }

  post {
    failure {
      echo "Deployment failed. Please check logs."
    }
  }
}
