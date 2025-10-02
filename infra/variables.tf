# --------------------------
# EC2 Instance Type
# --------------------------
variable "instance_type" {
  description = "EC2 instance type for manager and worker nodes"
  type        = string
  default     = "t3.micro"
}

# --------------------------
# SSH Public Key
# --------------------------
variable "ssh_public_key_path" {
  description = "Path to SSH public key file for AWS key pair. Can be injected via CI/CD."
  type        = string
  default     = ""  # Leave empty and pass via TF_VAR_ssh_public_key_path in Jenkins
}

variable "ssh_public_key" {
  description = "SSH public key content for AWS key pair (optional). Takes precedence over ssh_public_key_path."
  type        = string
  default     = ""
}

# --------------------------
# SSH Private Key (for worker nodes)
# --------------------------
variable "private_key" {
  description = "Private key content for connecting to worker nodes (used by null_resource). Inject via CI/CD."
  type        = string
  default     = ""
}

# --------------------------
# Worker Node Count
# --------------------------
variable "worker_count" {
  description = "Number of Docker Swarm worker nodes"
  type        = number
  default     = 2
}
