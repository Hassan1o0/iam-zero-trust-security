# Admin Group
resource "aws_iam_group" "admins" {
  name = "${local.project_name}-admins"
  path = "/admin/"
}

# Developer Group
resource "aws_iam_group" "developers" {
  name = "${local.project_name}-developers"
  path = "/developers/"
}

# Read-only Group
resource "aws_iam_group" "readonly" {
  name = "${local.project_name}-readonly"
  path = "/readonly/"
}

# Group Memberships
resource "aws_iam_group_membership" "admin_members" {
  name = "${local.project_name}-admin-membership"
  users = [for user in aws_iam_user.admin_users : user.name]
  group = aws_iam_group.admins.name
}

resource "aws_iam_group_membership" "developer_members" {
  name = "${local.project_name}-developer-membership"
  users = [for user in aws_iam_user.developer_users : user.name]
  group = aws_iam_group.developers.name
}

resource "aws_iam_group_membership" "readonly_members" {
  name = "${local.project_name}-readonly-membership"
  users = [for user in aws_iam_user.readonly_users : user.name]
  group = aws_iam_group.readonly.name
}
