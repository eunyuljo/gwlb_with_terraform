# Security Group for EC2 - Partner
resource "aws_security_group" "partner_ec2_sg" {
  name   = "partner_ec2_sg"
  vpc_id = module.partner_vpc.vpc_id

  ingress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "partner_ec2_sg"
  }
}


resource "aws_instance" "nginx_appliance" {
  ami                  = "ami-0023481579962abd4" # Amazon Linux 2 AMI (리전 확인 필요)
  instance_type        = "t3.medium"
  subnet_id            = module.partner_vpc.private_subnets[0]
  vpc_security_group_ids = [aws_security_group.partner_ec2_sg.id]
  iam_instance_profile = aws_iam_instance_profile.ssm_instance_profile.name

  user_data = <<-EOT
              #!/bin/bash
              yum update -y
              yum install -y nginx tcpdump nginx-mod-stream
              cat <<EOF > /etc/nginx/nginx.conf
              user nginx;
              worker_processes auto;
              error_log /var/log/nginx/error.log notice;
              pid /run/nginx.pid;
              include /usr/share/nginx/modules/*.conf;
              events {
                  worker_connections 1024;
              }
              http {
                  log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';
                  access_log  /var/log/nginx/access.log  main;
                  sendfile            on;
                  tcp_nopush          on;
                  keepalive_timeout   65;
                  types_hash_max_size 4096;
                  include             /etc/nginx/mime.types;
                  default_type        application/octet-stream;
                  include /etc/nginx/conf.d/*.conf;
                  server {
                      listen       80;
                      listen       [::]:80;
                      server_name  _;
                      root         /usr/share/nginx/html;
                      include /etc/nginx/default.d/*.conf;
                      error_page 404 /404.html;
                      location = /404.html {
                      }
                      error_page 500 502 503 504 /50x.html;
                      location = /50x.html {
                      }
                  }
              }
              stream {
                  log_format geneve_log '\$remote_addr [\$time_local] \$protocol '
                          '"\$status" \$bytes_sent';
                  access_log /var/log/nginx/geneve_access.log geneve_log;
                  server {
                      listen 6081 udp;
                      proxy_pass 127.0.0.1:80; # HTTP 포트로 전달
                  }
                  server {
                      listen 6081;
                      return 200; # TCP 6081 헬스 체크에 성공 응답
                  }
              }
              EOF

              # NGINX 시작
              systemctl daemon-reload
              systemctl enable nginx
              systemctl start nginx
                
              # GENEVE 포트 캡처를 위한 tcpdump 설정
              cat <<EOF > /etc/systemd/system/geneve-tcpdump.service
              [Unit]
              Description=GENEVE Traffic Capture
              After=network.target

              [Service]
              ExecStart=/usr/sbin/tcpdump -i ens5 port 6081 -w /var/log/geneve_traffic.pcap
              Restart=always

              [Install]
              WantedBy=multi-user.target
              EOF

              systemctl daemon-reload
              systemctl enable geneve-tcpdump
              systemctl start geneve-tcpdump

              # 디버깅용 로깅
              echo "GENEVE and NGINX Setup Completed" >> /var/log/setup.log
            EOT
  tags = {
    Name = "NGINX-Appliance"
  }

  # 필요 시 다른 리소스와의 의존성 추가 (예: GWLB Target Group)
  depends_on = [aws_lb_target_group.gwlb_target_group]
}
