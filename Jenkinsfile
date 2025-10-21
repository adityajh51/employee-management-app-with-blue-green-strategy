pipeline {
  agent any

  parameters {
    choice(name: 'TF_ACTION', choices: ['apply', 'destroy'], description: 'Choose Terraform action')
    choice(name: 'DEPLOY_COLOR', choices: ['blue', 'green'], description: 'Choose which stack to deploy (used only for apply)')
  }

  environment {
    REGISTRY = "adityahiremath51"
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
      when { expression { params.TF_ACTION == 'apply' } }
      parallel {
        stage('Backend Build') {
          steps {
            dir('backend') {
              sh 'mvn clean package -DskipTests'
            }
          }
        }
        stage('Frontend Build') {
          steps {
            dir('frontend') {
              sh '''
                npm install
                npm run build || echo "Skipping build if not configured"
              '''
            }
          }
        }
      }
    }

    stage('Build & Push Images') {
      when { expression { params.TF_ACTION == 'apply' } }
      steps {
        script {
          def version = "v${env.BUILD_NUMBER}"
          env.APP_VERSION = version
          withCredentials([usernamePassword(credentialsId: 'docker_creds',
                                             usernameVariable: 'DOCKER_USER',
                                             passwordVariable: 'DOCKER_PASS')]) {
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

    stage('Terraform Action') {
      steps {
        dir("${TF_DIR}") {
          withCredentials([aws(accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                               credentialsId: 'aws_creds',
                               secretKeyVariable: 'AWS_SECRET_ACCESS_KEY')]) {
            sh """
              terraform init
              terraform ${params.TF_ACTION} -auto-approve
            """
          }
        }
      }
    }

    stage('Get Manager IP') {
      when { expression { params.TF_ACTION == 'apply' } }
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
      when { expression { params.TF_ACTION == 'apply' } }
      steps {
        sshagent(['swarm_key']) {
          sh "bash scripts/deploy.sh ${MANAGER_IP} ${APP_VERSION} ${params.DEPLOY_COLOR}"
        }
      }
    }
  }

  post {
    failure {
      echo "❌ Deployment failed. Please check pipeline logs."
    }
    success {
      echo "✅ Pipeline completed successfully!"
    }
  }
}
