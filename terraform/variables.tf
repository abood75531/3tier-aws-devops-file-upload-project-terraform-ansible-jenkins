variable "region" {
  default = "ap-south-1"
}

variable "ami_id" {
  description = "Amazon Linux 2 AMI ID"
  default     = "ami-00ca570c1b6d79f36"
}

variable "instance_type" {
  default = "t2.micro"
}

variable "key_name" {
  description = "terraform"
    default     = "terraform"
}

variable "admin_email" {
    description = "Admin contact email"
    default     = "mahishelke05@gmail.com"
}
