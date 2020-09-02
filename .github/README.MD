# Terraflops Terraform Module
 
### Module name

Creates the required Lambda, IAM roles, IAM policies, SQS queue, Sumologic HTTP Source and Cloudwatch LogGroups required to stream logs to Sumologic
#### Example usage

```hcl-terraform
module "cloudwatch_logs" {
  source = "git::https://github.com/TerraFlops/sumo-logic-cloudwatch?ref=v1.0"

  name = "sumologic-cloudwatch"
  description = "sumologic-cloudwatch"
  collector_id = "108160862"

  log_groups = {
    SandboxFlowLogs = {
      filter_pattern = ""
    }
  }
}
```
