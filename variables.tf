variable "collector_name" {
  type = string
  description = "Name for an existing collector, defaults to the name if not provided"
  default = ""
}

variable "name" {
  type = string
  description = "Name for the polling source"
}

variable "description" {
  type = string
  description = "Description of the source"
}

variable "category" {
  type = string
  description = "The source category this source logs to."
  default = ""
}

variable "log_format" {
  type = string
  description = "For VPC logs, choose either VPC-JSON (JSON format) or VPC-RAW (raw messages). The default value is Others."
  default = "Others"
}

variable "include_log_info" {
  type = bool
  description = "Set to true to include loggroup/logstream values in logs. The default value is False. For AWS Lambda Logs IncludeLogGroupInfo must be set to True; for VPC Flow Logs it's optional."
  default = false
}

variable "log_stream_prefix" {
  type = string
  description = "List of logStream name prefixes"
  default = ""
}

variable "log_groups" {
  type = map(object({
    filter_pattern = string
  }))
  description = "Object of the log group name and filter pattern, used to send logs to sumologic"
  default = {}
}

variable "collector_id" {
  type = string
  description = "The ID for the associated sumologic collector"
}
