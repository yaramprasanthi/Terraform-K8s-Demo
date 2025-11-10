pipeline {
    agent any

    parameters {
        string(name: 'CLUSTER_NAME', defaultValue: 'eks-demo', description: 'EKS Cluster Name')
        choice(name: 'ENVIRONMENT', choices: ['dev', 'staging', 'prod'], description: 'Select Environment')
    }

    environment {
        AWS_REGION = 'ap-south-1'
        AWS_CREDS = credentials('aws-access-key') // AWS Access Key stored in Jenkins
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

        stage('Ensure S3 Backend Exists') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-access-key',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    sh '''
                    aws s3 ls s3://jenkins-eks-terraform-state || \
                    aws s3api create-bucket --bucket jenkins-eks-terraform-state \
                                             --region ${AWS_REGION} \
                                             --create-bucket-configuration LocationConstraint=${AWS_REGION}
                    '''
                }
            }
        }

        stage('Terraform Init') {
            steps {
                dir('terraform') {
                    withCredentials([[
                        $class: 'AmazonWebServicesCredentialsBinding',
                        credentialsId: 'aws-access-key',
                        accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                        secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                    ]]) {
                        sh 'terraform init -backend-config=region=${AWS_REGION} -reconfigure'
                    }
                }
            }
        }

        stage('Terraform Apply') {
            steps {
                dir('terraform') {
                    withCredentials([[
                        $class: 'AmazonWebServicesCredentialsBinding',
                        credentialsId: 'aws-access-key',
                        accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                        secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                    ]]) {
                        sh """
                        terraform workspace select ${ENVIRONMENT} || terraform workspace new ${ENVIRONMENT}
                        terraform plan -var-file=envs/${ENVIRONMENT}.tfvars -var="cluster_name=${CLUSTER_NAME}" -out=tfplan
                        terraform apply -auto-approve tfplan
                        """
                    }
                }
            }
        }

        stage('Update Kubeconfig') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-access-key',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    sh 'aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${AWS_REGION}'
                }
            }
        }

        stage('Build & Push Docker Image') {
            steps {
                dir('app') {
                    withCredentials([[
                        $class: 'AmazonWebServicesCredentialsBinding',
                        credentialsId: 'aws-access-key',
                        accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                        secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                    ]]) {
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

        stage('Rollback if Failed') {
            when {
                expression { currentBuild.result == 'FAILURE' }
            }
            steps {
                echo "Rolling back deployment..."
                dir('terraform') {
                    withCredentials([[
                        $class: 'AmazonWebServicesCredentialsBinding',
                        credentialsId: 'aws-access-key',
                        accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                        secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                    ]]) {
                        sh """
                        terraform destroy -auto-approve || true
                        """
                    }
                }
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
