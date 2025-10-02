# --------------------------
# AWS Key Pair
# --------------------------
resource "aws_key_pair" "swarm_key" {
  key_name   = "swarm-key"
  public_key = file(var.ssh_public_key_path)
}

# --------------------------
# AMI Data
# --------------------------
data "aws_ami" "ami_id" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# --------------------------
# Security Group
# --------------------------
locals {
  ingress_rules = [
    { port = 22,    protocal = "tcp" },
    { port = 2377,  protocal = "tcp" },
    { port = 7946,  protocal = "tcp" },
    { port = 7946,  protocal = "udp" },
    { port = 4789,  protocal = "udp" }
  ]
}

resource "aws_security_group" "swarm_sg" {
  name        = "swarm-sg"
  description = "Allow Docker Swarm traffic"

  dynamic "ingress" {
    for_each = local.ingress_rules
    content {
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = ingress.value.protocal
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --------------------------
# Manager Node
# --------------------------
resource "aws_instance" "manager" {
  ami                    = data.aws_ami.ami_id.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.swarm_key.key_name
  vpc_security_group_ids = [aws_security_group.swarm_sg.id]
  user_data              = file("${path.module}/user_data_manager.sh")

  tags = {
    Name = "swarm-manager"
  }

  depends_on = [aws_security_group.swarm_sg]
}

# --------------------------
# Worker Nodes
# --------------------------
resource "aws_instance" "workers" {
  count                  = var.worker_count
  ami                    = data.aws_ami.ami_id.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.swarm_key.key_name
  vpc_security_group_ids = [aws_security_group.swarm_sg.id]
  user_data              = file("${path.module}/user_data_worker.sh")

  tags = {
    Name = "swarm-worker-${count.index + 1}"
  }

  depends_on = [aws_instance.manager]
}

# --------------------------
# Wait for Swarm Manager
# --------------------------
resource "null_resource" "wait_for_swarm_manager" {
  depends_on = [aws_instance.manager]

  connection {
    type  = "ssh"
    host  = aws_instance.manager.public_ip
    user  = "ec2-user"
    agent = true # Uses SSH agent (Jenkins ssh-agent)
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for Docker to be installed on manager...'",
      "for i in {1..24}; do if command -v docker >/dev/null 2>&1; then echo 'Docker binary found.'; break; else echo 'Docker not installed yet...'; sleep 5; fi; done",
      "echo 'Waiting for Docker service to be active on manager...'",
      "sudo systemctl is-active docker >/dev/null 2>&1 || sudo systemctl start docker",
      "for i in {1..12}; do if sudo systemctl is-active docker >/dev/null 2>&1; then echo 'Docker service is running.'; break; else echo 'Docker service not active yet...'; sleep 5; fi; done",
      "echo 'Waiting for Swarm to be initialized on manager...'",
      "for i in {1..24}; do if sudo docker info 2>/dev/null | grep -q 'Swarm: active'; then echo 'Swarm is active.'; break; else echo 'Swarm not active yet...'; sleep 5; fi; done"
    ]
  }
}

# --------------------------
# Get Worker Join Token (using ssh-agent)
# --------------------------
data "external" "swarm_worker_token" {
  program = [
    "bash", "-c",
    <<EOT
    TOKEN=$(ssh -o StrictHostKeyChecking=no ec2-user@${aws_instance.manager.public_ip} 'sudo docker swarm join-token -q worker')
    echo "{\"token\":\"$TOKEN\"}"
    EOT
  ]
  depends_on = [
    aws_instance.manager,
    null_resource.wait_for_swarm_manager
  ]
}

# --------------------------
# Join Worker Nodes
# --------------------------
resource "null_resource" "join_workers" {
  depends_on = [aws_instance.manager, aws_instance.workers]

  for_each = { for idx, inst in aws_instance.workers : idx => inst }

  connection {
    type        = "ssh"
    host        = each.value.public_ip
    user        = "ec2-user"
    private_key = var.private_key # Injected from Jenkins or TF_VAR_private_key
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for Docker to be installed on worker...'",
      "for i in {1..24}; do if command -v docker >/dev/null 2>&1; then echo 'Docker binary found.'; break; else echo 'Docker not installed yet...'; sleep 5; fi; done",
      "echo 'Waiting for Docker service to be active...'",
      "sudo systemctl is-active docker >/dev/null 2>&1 || sudo systemctl start docker",
      "for i in {1..12}; do if sudo systemctl is-active docker >/dev/null 2>&1; then echo 'Docker service is running.'; break; else echo 'Docker service not active yet...'; sleep 5; fi; done",
      "echo 'Joining worker to the swarm...'",
      "sudo docker swarm join --token ${data.external.swarm_worker_token.result["token"]} ${aws_instance.manager.public_ip}:2377"
    ]
  }
}
