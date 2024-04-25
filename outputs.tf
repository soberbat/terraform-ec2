output "alb_dns_name" {
  value = aws_alb.load-balancer.dns_name
}

output "subnets" {
  value = data.aws_subnets.default-subnets.ids

}
