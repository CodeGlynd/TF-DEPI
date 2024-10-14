variable "azs" {
  description = "List of Availability Zones"
  default     = ["us-east-1a", "us-east-1b"]
}

variable "instance_type" {
  description = "EC2 instance type"
  default     = "t2.micro"
}
