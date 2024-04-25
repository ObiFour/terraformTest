#### EC2 ####

resource "aws_instance" "backend_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.medium"
  subnet_id = aws_subnet.private_subnet.id

  tags = {
    Name = "Backend Test"
  }

    root_block_device {
    volume_size = 8
  }

   user_data = <<-EOF
    #!/bin/bash
    set -ex
    sudo apt update && apt upgrade -y
    sudo apt install docker.io -y
    sudo service docker start
    sudo docker pull opsejf1/backend-image:latest
    sudo docker run -d -p 8080:8080 opsejf1/backend-image
  EOF

  vpc_security_group_ids = [
    module.ec2_sg.security_group_id,
    module.dev_ssh_sg.security_group_id
  ]

  key_name                = "terraformKey"
  monitoring              = true
  disable_api_termination = false
  ebs_optimized           = true
}