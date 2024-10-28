terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  required_version = ">= 1.2.0"
}


provider "aws" {
  region  = var.aws_region
}

module "resources" {
  source = "./general-resources"

  region = var.aws_region
  botTokenDev = var.botTokenDev
  botTokenProd = var.botTokenProd
  env    = var.env
}

resource "aws_instance" "jenkins" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_ids[0]
#  vpc_security_group_ids = [var.k8s_security_group_id] change to somthing match
  key_name               = var.key_pair_name
#  iam_instance_profile   = aws_iam_instance_profile.control_plane_profile.name  change to somthing match
  user_data              = file("install_docker.sh")

  tags = {
    Name = "jenkins-server"
  }

  root_block_device {
    volume_size = 20
  }

#  user_data = templatefile("./node-bootstrap.sh", {
#    aws_region = var.aws_region
#    k8s_version = var.k8s_version
#  }) change to jenkins sh
}

resource "aws_eip" "jenkins_server" {
  instance = aws_instance.jenkins.id
  domain   = "vpc"
}

resource "aws_instance" "control_plane" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_ids[0]
  vpc_security_group_ids = [var.k8s_security_group_id]
  key_name               = var.key_pair_name
  iam_instance_profile   = aws_iam_instance_profile.control_plane_profile.name

  tags = {
    Name = "${var.cluster_name}-control-plane"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }

  root_block_device {
    volume_size = 20
  }

  user_data = templatefile("./node-bootstrap.sh", {
    aws_region = var.aws_region
    k8s_version = var.k8s_version
  })
}

#resource "aws_security_group" "tf-k8s-cluster-sg" {
#  name        = "tf-k8s-cluster-sg"
#  vpc_id      = "vpc-005f690a39a2f3204"
#  description = "SG for k8s cluster ec2s"
#
#  ingress {
#    from_port   = "22"
#    to_port     = "22"
#    protocol    = "tcp"
#    cidr_blocks = ["0.0.0.0/0"]
#  }
#
#  ingress {
#    from_port   = 0
#    to_port     = 65535
#    protocol    = "tcp"
#    self        = true
#  }
#
#  ingress {
#    from_port   = 0
#    to_port     = 65535
#    protocol    = "udp"
#    self        = true
#  }
#
#  egress {
#    from_port   = 0
#    to_port     = 0
#    protocol    = "-1"
#    cidr_blocks = ["0.0.0.0/0"]
#  }
#}

resource "aws_iam_instance_profile" "control_plane_profile" {
  name = "control_plane_instance_profile"
  role = aws_iam_role.tf-control-plane-role.name
}

resource "aws_iam_role" "tf-control-plane-role" {
  name               = "tf-maayana-control-plane-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

data "aws_iam_policy" "AmazonEKSClusterPolicy" {
  name = "AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "attach_control_plane_role_1" {
  role       = aws_iam_role.tf-control-plane-role.name
  policy_arn = data.aws_iam_policy.AmazonEKSClusterPolicy.arn
}

data "aws_iam_policy" "AmazonEBSCSIDriverPolicy" {
  name = "AmazonEBSCSIDriverPolicy"
}

resource "aws_iam_role_policy_attachment" "attach_control_plane_role_2" {
  role       = aws_iam_role.tf-control-plane-role.name
  policy_arn = data.aws_iam_policy.AmazonEBSCSIDriverPolicy.arn
}

data "aws_iam_policy" "AmazonEC2ContainerRegistryReadOnly" {
  name = "AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "attach_control_plane_role_3" {
  role       = aws_iam_role.tf-control-plane-role.name
  policy_arn = data.aws_iam_policy.AmazonEC2ContainerRegistryReadOnly.arn
}

resource "aws_iam_policy" "tf-cert-manager" {
  name        = "tf-cert-manager"
  path        = "/"
  description = "allows to control-plane ec2s required access to cert manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement =  [
        {
            "Sid": "ACMReadOnlyAccess",
            "Effect": "Allow",
            "Action": [
                "acm:DescribeCertificate",
                "acm:ListCertificates",
                "acm:GetCertificate",
                "acm:ListTagsForCertificate",
                "acm:GetAccountConfiguration"
            ],
            "Resource": "*"
        }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_control_plane_role_cert_manager" {
  role       = aws_iam_role.tf-control-plane-role.name
  policy_arn = aws_iam_policy.tf-cert-manager.arn
}

resource "aws_instance" "worker_node" {
  # number of worker nodes to provision
  count = 2

  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_ids[count.index % length(var.public_subnet_ids)]
  vpc_security_group_ids = [var.k8s_security_group_id]
  key_name               = var.key_pair_name
  iam_instance_profile   = aws_iam_instance_profile.worker_node_profile.name

  tags = {
    Name = "${var.cluster_name}-worker-node-${count.index}"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }

  root_block_device {
    volume_size = 20
  }

  user_data = templatefile("./node-bootstrap.sh", {
    aws_region = var.aws_region
    k8s_version = var.k8s_version
  })
}

resource "aws_iam_instance_profile" "worker_node_profile" {
  name = "worker_node_instance_profile"
  role = aws_iam_role.tt-worker-node-role.name
}

resource "aws_iam_role" "tt-worker-node-role" {
  name               = "tf-maayana-worker-node-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "attach_worker_node_role_1" {
  role       = aws_iam_role.tt-worker-node-role.name
  policy_arn = data.aws_iam_policy.AmazonEBSCSIDriverPolicy.arn
}

resource "aws_iam_role_policy_attachment" "attach_worker_node_role_2" {
  role       = aws_iam_role.tt-worker-node-role.name
  policy_arn = data.aws_iam_policy.AmazonEC2ContainerRegistryReadOnly.arn
}

data "aws_iam_policy" "AmazonEKSWorkerNodePolicy" {
  name = "AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "attach_worker_node_role_3" {
  role       = aws_iam_role.tt-worker-node-role.name
  policy_arn = data.aws_iam_policy.AmazonEKSWorkerNodePolicy.arn
}

resource "aws_iam_policy" "tf-polybot-secrets-manager" {
  name        = "tf-maayana-polybot-secrets-manager"
  path        = "/"
  description = "allows to polybot ec2s required access to secrets manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement =  [
        {
            "Effect": "Allow",
            "Action": [
                "secretsmanager:GetResourcePolicy",
                "secretsmanager:GetSecretValue",
                "secretsmanager:DescribeSecret",
                "secretsmanager:ListSecretVersionIds"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": "secretsmanager:ListSecrets",
            "Resource": "*"
        }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_worker_node_role_secrets_manager" {
  role       = aws_iam_role.tt-worker-node-role.name
  policy_arn = aws_iam_policy.tf-polybot-secrets-manager.arn
}

resource "aws_iam_role_policy_attachment" "attach_control_plane_role_secrets_manager" {
  role       = aws_iam_role.tf-control-plane-role.name
  policy_arn = aws_iam_policy.tf-polybot-secrets-manager.arn
}

resource "aws_iam_policy" "tf-polybot-s3" {
  name        = "tf-maayana-polybot-s3"
  path        = "/"
  description = "allows to polybot ec2s required access to s3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement =  [
        {
            "Sid": "ListObjectsInBucket",
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket"
            ],
            "Resource": "*"
        },
        {
            "Sid": "WriteAction",
            "Effect": "Allow",
            "Action": "s3:PutObject",
            "Resource": "*"
        },
        {
            "Sid": "ReadAccessFromImagesFold",
            "Effect": "Allow",
            "Action": "s3:GetObject",
            "Resource": "*"
        }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_worker_node_role_s3" {
  role       = aws_iam_role.tt-worker-node-role.name
  policy_arn = aws_iam_policy.tf-polybot-s3.arn
}


resource "aws_iam_policy" "tf-polybot-sqs" {
  name        = "tf-maayana-polybot-sqs"
  path        = "/"
  description = "allows to polybot ec2s required access to sqs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement =  [
        {
            "Sid": "AmazonSQSGeneralPremissions",
            "Effect": "Allow",
            "Action": [
                "sqs:GetQueueAttributes",
                "sqs:GetQueueUrl",
                "sqs:ListQueues"
            ],
            "Resource": "*"
        },
        {
            "Sid": "AmazonSQSWritePremissions",
            "Effect": "Allow",
            "Action": [
                "sqs:SendMessage",
                "sqs:ReceiveMessage",
                "sqs:DeleteMessage"
            ],
            "Resource": "*"
        }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_worker_node_role_sqs" {
  role       = aws_iam_role.tt-worker-node-role.name
  policy_arn = aws_iam_policy.tf-polybot-sqs.arn
}


resource "aws_iam_policy" "tf-polybot-dynamo" {
  name        = "tf-maayana-polybot-dynamo"
  path        = "/"
  description = "allows to polybot ec2s required access to dynamo"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement =  [
        {
            "Sid": "ListAndDescribe",
            "Effect": "Allow",
            "Action": [
                "dynamodb:List*",
                "dynamodb:DescribeReservedCapacity*",
                "dynamodb:DescribeLimits",
                "dynamodb:DescribeTimeToLive"
            ],
            "Resource": "*"
        },
        {
            "Sid": "SpecificTable",
            "Effect": "Allow",
            "Action": [
                "dynamodb:GetItem",
                "dynamodb:Query",
                "dynamodb:Scan",
                "dynamodb:PutItem",
                "dynamodb:UpdateItem"
            ],
            "Resource": "*"
        }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_worker_node_role_dynamo" {
  role       = aws_iam_role.tt-worker-node-role.name
  policy_arn = aws_iam_policy.tf-polybot-dynamo.arn
}

resource "aws_iam_policy" "tf-cloud-watch-access" {
  name        = "tf-cloud-watch-access"
  path        = "/"
  description = "allows access to cloud watch logs & metrics for grafana"

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "AllowReadingMetricsFromCloudWatch",
        "Effect": "Allow",
        "Action": [
          "cloudwatch:DescribeAlarmsForMetric",
          "cloudwatch:DescribeAlarmHistory",
          "cloudwatch:DescribeAlarms",
          "cloudwatch:ListMetrics",
          "cloudwatch:GetMetricData",
          "cloudwatch:GetInsightRuleReport"
        ],
        "Resource": "*"
      },
      {
        "Sid": "AllowReadingResourceMetricsFromPerformanceInsights",
        "Effect": "Allow",
        "Action": "pi:GetResourceMetrics",
        "Resource": "*"
      },
      {
        "Sid": "AllowReadingLogsFromCloudWatch",
        "Effect": "Allow",
        "Action": [
          "logs:DescribeLogGroups",
          "logs:GetLogGroupFields",
          "logs:StartQuery",
          "logs:StopQuery",
          "logs:GetQueryResults",
          "logs:GetLogEvents"
        ],
        "Resource": "*"
      },
      {
        "Sid": "AllowReadingTagsInstancesRegionsFromEC2",
        "Effect": "Allow",
        "Action": ["ec2:DescribeTags", "ec2:DescribeInstances", "ec2:DescribeRegions"],
        "Resource": "*"
      },
      {
        "Sid": "AllowReadingResourcesForTags",
        "Effect": "Allow",
        "Action": "tag:GetResources",
        "Resource": "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_worker_node_role_cloud_watch" {
  role       = aws_iam_role.tt-worker-node-role.name
  policy_arn = aws_iam_policy.tf-cloud-watch-access.arn
}