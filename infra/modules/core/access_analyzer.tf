# IAM Access Analyzer
resource "aws_accessanalyzer_analyzer" "account" {
  analyzer_name = "account-access-analyzer"
  type          = "ACCOUNT"

  tags = {
    Name = "account-access-analyzer"
  }
}
