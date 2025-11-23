variable "function_name" {
  type = string
}

variable "handler" {
  type    = string
  default = "index.handler"
}

variable "runtime" {
  type    = string
  default = "python3.11"
}

