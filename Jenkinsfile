pipeline {
    agent any

    stages {

        stage('Cleanup') {
            steps {
                deleteDir()   // remove old files
            }
        }

        stage('Checkout') {
            steps {
                checkout scm   // ✅ bring back repo
            }
        }

        stage('Debug') {
            steps {
                sh 'ls -la'   // should show docker-compose.yml
            }
        }

        stage('Build') {
            steps {
                sh 'docker compose build'
            }
        }
        stage('Test') {
            steps {
                sh '''
                python3 -m venv venv
                . venv/bin/activate
                export PYTHONPATH=$PWD
                pip install -r requirements.txt
                pytest tests/
                '''
            }
        }


        stage('Deploy') {
            steps {
                sh '''
                echo "Stopping old containers..."
                docker compose down --remove-orphans || true

                echo "Starting fresh containers..."
                docker compose up -d --build
                '''
            }
        }
    }
}