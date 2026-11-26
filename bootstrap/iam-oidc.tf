# bootstrap/iam-oidc.tf
# Creates the OIDC trust + IAM roles that the Azure DevOps pipeline assumes.
# One role per environment — least privilege.

variable "ado_org_name" {
  description = "Your Azure DevOps organisation name (e.g. mycompany)."
}

variable "ado_project_name" {
  description = "Your Azure DevOps project name (e.g. iac-platform)."
}

# ── OIDC Identity Provider for Azure DevOps ───────────────────────────────────
# Azure DevOps issues OIDC tokens that AWS can verify against this provider.

resource "aws_iam_openid_connect_provider" "ado" {
  url             = "https://vstoken.dev.azure.com/${var.ado_org_name}"
  client_id_list  = ["api://AzureADTokenExchange"]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"]
  # Thumbprint is for vstoken.dev.azure.com — verify at:
  # https://docs.microsoft.com/azure/devops/pipelines/library/connect-to-azure
}

# ── IAM role: nonprod ─────────────────────────────────────────────────────────

data "aws_iam_policy_document" "assume_nonprod" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.ado.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "vstoken.dev.azure.com/${var.ado_org_name}:aud"
      values   = ["api://AzureADTokenExchange"]
    }
    condition {
      test     = "StringLike"
      variable = "vstoken.dev.azure.com/${var.ado_org_name}:sub"
      # Only the iac-platform project's pipelines can assume this role
      values = ["sc://${var.ado_org_name}/${var.ado_project_name}/*"]
    }
  }
}

resource "aws_iam_role" "tf_nonprod" {
  name                 = "tf-nonprod-compute"
  assume_role_policy   = data.aws_iam_policy_document.assume_nonprod.json
  max_session_duration = 3600

  tags = { managed-by = "terraform", env = "nonprod" }
}

# Give nonprod role permissions it actually needs:
# EC2 + S3 + KMS read/write in nonprod, plus state bucket access.
resource "aws_iam_role_policy" "tf_nonprod_policy" {
  name = "tf-nonprod-compute-policy"
  role = aws_iam_role.tf_nonprod.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2andS3Nonprod"
        Effect = "Allow"
        Action = [
          "ec2:*", "s3:*", "kms:*",
          "iam:GetInstanceProfile", "iam:PassRole"
        ]
        Resource = "*"
        Condition = {
          StringEquals = { "aws:RequestedRegion" = "us-east-1" }
        }
      },
      {
        Sid    = "StateBackend"
        Effect = "Allow"
        Action = [
          "s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket",
          "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"
        ]
        Resource = [
          "arn:aws:s3:::${var.org}-tfstate-us-east-1-${var.account_suffix}",
          "arn:aws:s3:::${var.org}-tfstate-us-east-1-${var.account_suffix}/*",
          "arn:aws:dynamodb:us-east-1:*:table/${var.org}-tf-locks"
        ]
      }
    ]
  })
}

# ── IAM role: prod ────────────────────────────────────────────────────────────

data "aws_iam_policy_document" "assume_prod" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.ado.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "vstoken.dev.azure.com/${var.ado_org_name}:aud"
      values   = ["api://AzureADTokenExchange"]
    }
    condition {
      test     = "StringLike"
      variable = "vstoken.dev.azure.com/${var.ado_org_name}:sub"
      values   = ["sc://${var.ado_org_name}/${var.ado_project_name}/*"]
    }
  }
}

resource "aws_iam_role" "tf_prod" {
  name                 = "tf-prod-compute"
  assume_role_policy   = data.aws_iam_policy_document.assume_prod.json
  max_session_duration = 3600

  tags = { managed-by = "terraform", env = "prod" }
}

resource "aws_iam_role_policy" "tf_prod_policy" {
  name = "tf-prod-compute-policy"
  role = aws_iam_role.tf_prod.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2andS3Prod"
        Effect = "Allow"
        Action = [
          "ec2:*", "s3:*", "kms:*",
          "iam:GetInstanceProfile", "iam:PassRole"
        ]
        Resource = "*"
        Condition = {
          StringEquals = { "aws:RequestedRegion" = "us-east-1" }
        }
      },
      {
        Sid    = "StateBackend"
        Effect = "Allow"
        Action = [
          "s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket",
          "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"
        ]
        Resource = [
          "arn:aws:s3:::${var.org}-tfstate-us-east-1-${var.account_suffix}",
          "arn:aws:s3:::${var.org}-tfstate-us-east-1-${var.account_suffix}/*",
          "arn:aws:dynamodb:us-east-1:*:table/${var.org}-tf-locks"
        ]
      }
    ]
  })
}

output "nonprod_role_arn" { value = aws_iam_role.tf_nonprod.arn }
output "prod_role_arn" { value = aws_iam_role.tf_prod.arn }
