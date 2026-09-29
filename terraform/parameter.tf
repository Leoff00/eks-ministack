resource "aws_ssm_parameter" "numbers_parameter" {
  name    = "numbers"
  type    = "String"
  value   = "552177777777"
}