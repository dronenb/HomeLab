

resource "aws_secretsmanager_secret" "example" {
  name = "homelab-testing-aws"
}

resource "aws_secretsmanager_secret_version" "example" {
  secret_id     = aws_secretsmanager_secret.example.id
  secret_string = "example-string-to-protect"
}

# OIDC issuer
# Obtain fingerprint with:
# server=storage.googleapis.com
# openssl s_client -servername "${server}" -showcerts -connect "${server}":443 < /dev/null 2>/dev/null | \
#   openssl x509 -in /dev/stdin -fingerprint -sha1 -noout | \
#   sed 's/://g' | \
#   awk -F= '{print tolower($2)}'

resource "aws_iam_openid_connect_provider" "k3s" {
  url = "https://storage.googleapis.com/dronenb-k3s-homelab-wif-oidc"

  client_id_list = [
    "sts.amazonaws.com",
  ]

  thumbprint_list = ["cf23df2207d99a74fbe169e3eba035e633b65d94"]
}

resource "aws_iam_role" "kubernetes_secrets_role" {
  name = "kubernetes-secrets-role"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Federated" : "${aws_iam_openid_connect_provider.k3s.arn}"
        },
        "Action" : "sts:AssumeRoleWithWebIdentity",
        "Condition" : {
          "StringEquals" : {
            "storage.googleapis.com/dronenb-k3s-homelab-wif-oidc:sub" : "system:serviceaccount:default:default",
            "storage.googleapis.com/dronenb-k3s-homelab-wif-oidc:aud" : "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "policy" {
  name        = "secret_access_policy"
  path        = "/"
  description = "My test policy"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [{
      "Effect" : "Allow",
      "Action" : ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"],
      "Resource" : ["${aws_secretsmanager_secret.example.arn}"]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "secrets_policy_attachment" {
  role       = aws_iam_role.kubernetes_secrets_role.name
  policy_arn = aws_iam_policy.policy.arn
}
