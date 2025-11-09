pipeline {
    agent any

    parameters {
        string(name: 'CLUSTER_NAME', defaultValue: 'eks-demo', description: 'EKS Cluster Name')
        choice(name: 'ENVIRONMENT', choices: ['dev', 'staging', 'prod'], description: 'Select Environment')
    }

    environment {
        AWS_REGION = 'ap-south-1'
        AWS_CREDENTIALS = credentials('aws-access-key')
    }

    triggers {
        githubPush()
    }

    stages {
        stage('Checkout Code') {
            steps {
                git branch: 'main', url: 'https://github.com/yaramprasanthi/Terraform-K8s-Demo.git'
            }
        }

        stage('Terraform Init') {
            steps {
                dir('terraform') {
                    sh 'terraform init -backend-config=region=${AWS_REGION}'
                }
            }
        }

        stage('Terraform Apply') {
            steps {
                dir('terraform') {
                    sh """
                        terraform workspace select ${ENVIRONMENT} || terraform workspace new ${ENVIRONMENT}
                        terraform plan -var-file=envs/${ENVIRONMENT}.tfvars -var="cluster_name=${CLUSTER_NAME}" -out=tfplan
                        terraform apply -auto-approve tfplan
                    """
                }
            }
        }

        stage('Build & Push Docker Image') {
            steps {
                dir('app') {
                    sh """
                        docker build -t ${CLUSTER_NAME}-app .
                        aws ecr create-repository --repository-name ${CLUSTER_NAME}-app --region ${AWS_REGION} || true
                        docker tag ${CLUSTER_NAME}-app:latest 051701863592.dkr.ecr.${AWS_REGION}.amazonaws.com/${CLUSTER_NAME}-app:latest
                        aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin 051701863592.dkr.ecr.${AWS_REGION}.amazonaws.com
                        docker push 051701863592.dkr.ecr.${AWS_REGION}.amazonaws.com/${CLUSTER_NAME}-app:latest
                    """
                }
            }
        }

        stage('Deploy with Helm') {
            steps {
                dir('app/helm') {
                    sh """
                        helm upgrade --install ${CLUSTER_NAME}-app . \
                            --set image.repository=051701863592.dkr.ecr.${AWS_REGION}.amazonaws.com/${CLUSTER_NAME}-app \
                            --set image.tag=latest \
                            --namespace default --create-namespace
                    """
                }
            }
        }

        stage('Validate Deployment') {
            steps {
                sh "kubectl get pods -o wide"
                sh "kubectl get svc"
            }
        }

        stage('Rollback if Failed') {
            when {
                expression { currentBuild.result == 'FAILURE' }
            }
            steps {
                echo "Rolling back deployment..."
                sh "helm rollback ${CLUSTER_NAME}-app 1 || terraform destroy -auto-approve"
            }
        }
    }

    post {
        success {
            echo "✅ Deployment succeeded!"
        }
        failure {
            echo "❌ Deployment failed!"
        }
    }
}

