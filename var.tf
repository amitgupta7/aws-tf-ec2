variable "access_key" {
  description = "aws access key"
  type = string
}

variable "secret_key" {
  description = "aws secret key"
  type = string
}

variable "region" {
  description = "aws region"
  type = string
  default = "us-west-1"
}