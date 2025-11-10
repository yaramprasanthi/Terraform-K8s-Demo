pipeline {
    agent any

    parameters {
        string(name: 'CLUSTER_NAME', defaultValue: 'eks-demo', description: 'EKS Cluster Name')
        choice(name: 'ENVIRONMENT', choices: ['dev', 'staging', 'prod'], description: 'Select Environment')
    }

    environment {
        AWS_REGION = 'ap-south-1'
    }

    triggers {
        githubPush()
    }

    stages {
        stage('Checkout Code') {
            steps {
                // Clean workspace first to avoid git corruption
                deleteDir()
                git branch: 'main', url: 'https://github.com/yaramprasanthi/Terraform-K8s-Demo.git'
            }
        }

        stage('Terraform Init') {
            steps {
                dir('terraform') {
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-access-key']]) {
                        sh 'terraform init -backend-config=region=${AWS_REGION}'
                    }
                }
            }
        }

        stage('Terraform Apply') {
            steps {
                dir('terraform') {
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-access-key']]) {
                        sh """
                            terraform workspace select ${ENVIRONMENT} || terraform workspace new ${ENVIRONMENT}
                            terraform plan -var-file=envs/${ENVIRONMENT}.tfvars -var="cluster_name=${CLUSTER_NAME}" -out=tfplan
                            terraform apply -auto-approve tfplan
                        """
                    }
                }
            }
        }

        stage('Build & Push Docker Image') {
            steps {
                dir('app') {
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-access-key']]) {
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
    }

    post {
        success {
            echo "✅ Deployment succeeded for ${ENVIRONMENT} → Cluster: ${CLUSTER_NAME}"
        }
        failure {
            echo "❌ Deployment failed for ${ENVIRONMENT} → Cluster: ${CLUSTER_NAME}"
            
            script {
                echo "Rolling back deployment..."
                // Attempt Helm rollback first, then Terraform destroy if Helm fails
                try {
                    sh "helm rollback ${CLUSTER_NAME}-app 1 || true"
                    dir('terraform') {
                        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-access-key']]) {
                            sh 'terraform destroy -auto-approve'
                        }
                    }
                } catch (err) {
                    echo "Rollback failed: ${err}"
                }
            }
        }
    }
}
