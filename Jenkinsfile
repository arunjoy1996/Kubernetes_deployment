pipeline {
    agent {
        label 'jenkins-agent'
    }

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
                sh 'ls -la'   // should show project structure
            }
        }

        stage('Test') {
            steps {
                container('python') {
                    sh '''
                    python3 -m venv venv
                    . venv/bin/activate
                    export PYTHONPATH=$PWD
                    pip install -r requirements.txt
                    pytest tests/
                    '''
                }
            }
        }
        stage('Debug') {
            steps {
                container('docker') {
                    sh '''
                    echo "Container started"
                    whoami
                    pwd
                    ls -la
                    which sh
                    which docker
                    docker version || true
                    '''
                }
            }
        }
        stage('Build & Push') {
            steps {
                container('docker') {
                    withCredentials([usernamePassword(credentialsId: 'docker-hub-credentials', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                        sh '''
                        set -e
                        export IMAGE_TAG="${BUILD_NUMBER:-latest}"

                        echo "Checking Docker access..."
                        docker version
                        docker ps --format '{{.Names}}' || true

                        echo "Logging in to Docker Hub..."
                        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin

                        echo "Building Docker images..."
                        docker build -t "$DOCKER_USER/ml-api:${IMAGE_TAG}" .
                        docker build -t "$DOCKER_USER/nginx-frontend:${IMAGE_TAG}" -f nginx/Dockerfile .

                        echo "Pushing images to Docker Hub..."
                        docker push "$DOCKER_USER/ml-api:${IMAGE_TAG}"
                        docker push "$DOCKER_USER/nginx-frontend:${IMAGE_TAG}"
                        '''
                    }
                }
            }
        }

        stage('Deploy') {
            steps {
                container('kubectl') {
                    withCredentials([usernamePassword(credentialsId: 'docker-hub-credentials', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                        sh '''
                        set -e
                        export IMAGE_TAG="${BUILD_NUMBER:-latest}"

                        echo "Updating manifests with Docker Hub images..."
                        sed -Ei "s|image: .*ml-api.*|image: ${DOCKER_USER}/ml-api:${IMAGE_TAG}|g" kubernetes/ml-api.yaml
                        sed -Ei "s|image: .*nginx-frontend.*|image: ${DOCKER_USER}/nginx-frontend:${IMAGE_TAG}|g" kubernetes/nginx.yaml

                        echo "Applying Kubernetes manifests..."
                        kubectl apply -f kubernetes/ml-api.yaml
                        kubectl apply -f kubernetes/nginx.yaml
                        kubectl apply -f kubernetes/prometheus.yaml
                        kubectl apply -f kubernetes/loki.yaml
                        kubectl apply -f kubernetes/promtail.yaml
                        kubectl apply -f kubernetes/grafana.yaml
                        kubectl apply -f kubernetes/cadvisor.yaml

                        echo "Waiting for deployments to roll out..."
                        kubectl rollout status deployment/ml-api
                        kubectl rollout status deployment/nginx
                        '''
                    }
                }
            }
        }
    }
}
