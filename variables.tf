variable "instance_type" {
    description = "ec2 instance type"
    default     = "t2.micro"
  
}

variable "security_group_ingress" {
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = [ {
    from_port = 80
    to_port   = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  } ]
}
variable "security_group_egress" {
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = [ {
    from_port = 0
    to_port   = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  } ]
}

variable "asg_config" {
   type = map(object({
    name             = string
    min_size         = number
    max_size         = number
    desired_capacity = number
    azs              = list(string)
  }))

  default = {
    "asg1" = {
      name             = "nice-asg"
      min_size         = 2
      max_size         = 2
      desired_capacity = 2
      azs              = ["us-east-1a", "us-east-1b"]
    }
  }
}