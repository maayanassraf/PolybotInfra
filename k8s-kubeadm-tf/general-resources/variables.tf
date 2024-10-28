
variable "env" {
  description = "describe the environment type"
  type        = list(string)
}

variable "region" {
  description = "aws region"
  type        = string
}

variable "botTokenDev" {
  description = "bot token for env"
  type = string
}

variable "botTokenProd" {
  description = "bot token for env"
  type = string
}