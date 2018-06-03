variable "name" {
  type = "string"
  description = "The name for the application"
  default = "vpc"
}

variable "environment" {
  type = "string"
  description = "The environment of the application"
  default = "test"
}

variable "namespace" {
  type = "string"
  description = "The namespace for the application"
}

variable "tags" {
  type = "map"
  description = "describe your variable"
  default = {}
}

variable "cidr_block" {
  type = "string"
  description = "CIDR Block for the application VPC"
}

variable "amount_of_subnets" {
  description = "Amount of Subnets to create per type"
  default = 3
}

variable "enable_private_subnet" {
  description = "Create a Private subnet. Defaults to true"
  default = true
}

variable "enable_dns_hostnames" {
  description = "A boolean flag to enable/disable DNS hostnames in the VPC. Defaults true."
  default = true
}

variable "enable_dns_support" {
  description = "A boolean flag to enable/disable DNS support in the VPC. Defaults true."
  default = true
}

variable "enable_dynamodb_endpoint" {
  description = "Should be true if you want to provision a DynamoDB endpoint to the VPC"
  default     = false
}

variable "enable_s3_endpoint" {
  description = "Should be true if you want to provision a S3 endpoint to the VPC"
  default     = false
}

variable "enable_nat_gateway" {
  description = "Should be true if you want to provision NAT Gateways for each of your private networks"
  default     = false
}

variable "private_propagating_vgws" {
  description = "A list of VGWs the private route table should propagate"
  default     = []
}

variable "single_nat_gateway" {
  description = "Should be true if you want to provision a single shared NAT Gateway across all of your private networks"
  default     = false
}

