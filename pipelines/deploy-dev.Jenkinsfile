pipeline {
    agent {
       label 'general'
    }

    parameters {
        string(name: 'SERVICE_NAME', defaultValue: '', description: '')
        string(name: 'IMAGE_FULL_NAME_PARAM', defaultValue: '', description: '')
    }

    stages {
        stage('Git Setup') {
            steps {
                sh 'git checkout -b dev || git checkout main'
            }
        }
        stage('Update Yaml') {
            steps {
                sh '''
                  cd k8s/$SERVICE_NAME
                  sed -i "s|image: .*|image: ${IMAGE_FULL_NAME_PARAM}|" deployment.yaml

                  git config user.email "jenkins@noreply.com"
                  git config user.name "jenkins"
                  git add deployment.yaml
                  git commit -m "Jenkins deploy $SERVICE_NAME $IMAGE_FULL_NAME_PARAM"
                '''
            }
        }
        stage('Git push') {
            steps {
               withCredentials([usernamePassword(credentialsId: 'github', usernameVariable: 'GITHUB_USERNAME', passwordVariable: 'GITHUB_TOKEN')]) {
                 sh '''
                 git push https://$GITHUB_TOKEN@github.com/maayanassraf/PolybotInfra.git dev
                 '''
               }
            }
        }
    }
    post {
        cleanup {
            cleanWs()
        }
    }
}