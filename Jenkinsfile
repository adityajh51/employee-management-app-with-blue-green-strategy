pipeline {
  agent any

  properties([
    parameters([
      choice(
        name: 'TF_ACTION',
        choices: ['apply', 'destroy'],
        description: 'Choose Terraform action'
      ),
      cascadeChoiceParameter(
        name: 'DEPLOY_COLOR',
        description: 'Choose which stack to deploy',
        referencedParameters: 'TF_ACTION',
        choiceType: 'PT_SINGLE_SELECT',
        script: [
          $class: 'GroovyScript',
          script: [
            classpath: [],
            sandbox: true,
            script: '''
              // If TF_ACTION is "apply", return blue/green
              if (TF_ACTION == "apply") {
                return ["blue", "green"]
              } else {
                // Empty list hides parameter
                return []
              }
            '''
          ]
        ]
      )
    ])
  ])


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
      when { expression { params.TF_ACTION == 'apply' } }
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
      when { expression { params.TF_ACTION == 'apply' } }
      steps {
        script {
          def version = "v${env.BUILD_NUMBER}"
          env.APP_VERSION = version
          withCredentials([usernamePassword(credentialsId: 'docker_creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
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
        sshagent(['swarm_key']) {
          dir("${TF_DIR}") {
            withCredentials([aws(accessKeyVariable: 'AWS_ACCESS_KEY_ID', credentialsId: 'aws_creds', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY')]) {
              sh """
                terraform init
                terraform ${params.TF_ACTION} -auto-approve
              """
            }
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
          sh "bash scripts/deploy_blue_green.sh ${MANAGER_IP} ${APP_VERSION} ${params.DEPLOY_COLOR}"
        }
      }
    }
  }

  post {
    failure { echo "❌ Deployment failed. Please check logs." }
    success { echo "✅ Pipeline completed successfully." }
  }
}
