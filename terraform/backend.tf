terraform {
  backend "s3" {
    bucket = "jenkins-eks-terraform-state"
    key    = "eks/terraform.tfstate"
    region = "ap-south-1"
  }
}
