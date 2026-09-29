resource "aws_ecr_repository" "app" {
  name                 = "hello-eks"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true
}
