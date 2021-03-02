variable "cidr" {
  default = {
    us-east-1 = "172.20.0.0/24"
    us-east-2 = "172.20.1.0/24"
    ca-central-1 = "172.20.2.0/24"
  }
}
