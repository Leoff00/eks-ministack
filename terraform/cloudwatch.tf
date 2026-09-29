resource "aws_cloudwatch_log_group" "app" {
  name              = "/eks/ministack-lab/hello-eks"
  retention_in_days = 7
}
