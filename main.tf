provider "aws" {
  version = "~> 2.0"
  region = "eu-west-1"
}

resource "aws_vpc" "my_first_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "firstVPC"
  }
}
