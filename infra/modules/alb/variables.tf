variable "name" {
  type = string
}

variable "subnets" {
  type    = list(string)
  default = []
}

variable "env" {
  type    = string
}

variable "http_port" {
  type    = number
  default = 80
}

variable "protocol" {
  type    = string
  default = "HTTP"
}
