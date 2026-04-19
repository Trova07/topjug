variable "project" {
  type = string
}

variable "public_subnets" {
  type = list(string)
}

variable "rds_sg_id" {
  type = string
}

variable "db_name" {
  type = string
}

variable "db_username" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "db_instance" {
  type = string
}
