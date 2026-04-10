variable "cluster_name" {
  type = string
}

variable "container_name" {
  type = string
}

variable "container_image" {
  type = string
}

variable "container_port" {
  type = number
}

variable "desired_count" {
  type = number
}

variable "cpu" {
  type = string
}

variable "memory" {
  type = string
}

variable "subnets" {
  type = list(string)
}

variable "alb_target_group_arn" {
  type = string
}

variable "alb_security_group_id" {
  type = string
}

variable "assign_public_ip" {
  type = bool
}

variable "task_role_policy_arns" {
  type    = list(string)
  default = []
}

variable "env" {
  type = string
}
