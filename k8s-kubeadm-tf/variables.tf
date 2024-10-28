variable "k8s_version" {
    description = "The version of Kubernetes to deploy. Defaults to v1.30."
    type = string
    default = "v1.30"
}

variable "cluster_name" {
    description = "The name of your Kubernetes cluster (any name to your choice)"
    type = string
}

variable "aws_region" {
    description = "The AWS region to deploy in"
    type = string
}

variable "ami_id" {
    description = "The ID of the AMI to use for the nodes"
    type = string
}

variable "public_subnet_ids" {
    description = "List of public subnet IDs"
    type = list(string)
}

variable "key_pair_name" {
    description = "The name of the key pair to use for the instance"
    type = string
}

variable "instance_type" {
    description = "The type of instance to use"
    type = string
    default = "t3.medium"
}

variable "env" {
  description = "describe the environment type"
  type        = list(string)
}

variable "botTokenDev" {
  description = "bot token for env"
  type = string
}

variable "botTokenProd" {
  description = "bot token for env"
  type = string
}

variable "k8s_security_group_id" {
  description = "security group id for k8s cluster"
  type = string
}