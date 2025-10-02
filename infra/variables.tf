variable "instance_type" {
  default = "t3.micro"
}

variable "ssh_public_key_path" {
  default = "~/.ssh/id_rsa.pub"
}

variable "worker_count" {
  default = 2
}