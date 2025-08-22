variable "prefix" {
    description = "Resource name prefix"
    type = string
    default = "cm-kitagawa"
}

variable "domain_name" {
    description = "Domain name for SSL certificate"
    type = string
    default = ""
}

variable "enable_https" {
    description = "Enable HTTPS listener on ALB"
    type = bool
    default = false
}

