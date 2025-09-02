# Admin Users
resource "aws_iam_user" "admin_users" {
  for_each = toset(var.admin_users)
  
  name = each.value
  path = "/admin/"

  tags = merge(local.tags, {
    Name = each.value
    Role = "admin"
  })
}

# Developer Users
resource "aws_iam_user" "developer_users" {
  for_each = toset(var.developer_users)
  
  name = each.value
  path = "/developers/"

  tags = merge(local.tags, {
    Name = each.value
    Role = "developer"
  })
}

# Read-only Users
resource "aws_iam_user" "readonly_users" {
  for_each = toset(var.readonly_users)
  
  name = each.value
  path = "/readonly/"

  tags = merge(local.tags, {
    Name = each.value
    Role = "readonly"
  })
}

# Login Profile for MFA enforcement
resource "aws_iam_user_login_profile" "admin_profiles" {
  for_each = aws_iam_user.admin_users
  
  user    = each.value.name
  pgp_key = "keybase:${each.value.name}"  # Replace with actual PGP key or remove for testing
}

resource "aws_iam_user_login_profile" "developer_profiles" {
  for_each = aws_iam_user.developer_users
  
  user    = each.value.name
  pgp_key = "keybase:${each.value.name}"  # Replace with actual PGP key or remove for testing
}

resource "aws_iam_user_login_profile" "readonly_profiles" {
  for_each = aws_iam_user.readonly_users
  
  user    = each.value.name
  pgp_key = "keybase:${each.value.name}"  # Replace with actual PGP key or remove for testing
}
