locals {
  name = "pet-clinic"
}

data "aws_acm_certificate" "cert" {
  domain      = "dv-gidideals.co.uk"
  types       = ["AMAZON_ISSUED"]
  most_recent = true
}

# Include the keypair module for generating and managing SSH keys.
module "keypair" {
  source = "./module/keypair"
}

module "vpc" {
  source         = "./module/vpc"
  private-subnet = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  public-subnet  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  azs            = ["eu-central-1a", "eu-west-1b", "eu-west-1c"]
}

module "securitygroup" {
  source = "./module/securitygroup"
  vpc-id = module.vpc.vpc_id
}

module "sonarQube" {
  source       = "./module/sonaQube"
  ami          = "ami-01b32e912c60acdfa"
  sonarqube-sg = module.securitygroup.sonarqube-sg
  subnet_id    = module.vpc.publicsub2
  elb-subnets  = [module.vpc.publicsub1, module.vpc.publicsub2]
  cert-arn     = data.aws_acm_certificate.cert.arn
  name         = "${local.name}-sonarQube"
  keypair      = module.keypair.public-key-id
  nr-key       = "4243993"
  nr-acc-id    = "NRAK-HPT5OJANIT515S5M7XMTIRUERKX"
  nr-region    = "EU"
}

# Include the ASG for stage environment
module "asg-stg" {
  source          = "./module/stage-autoscaling"
  ami-stg         = "ami-05f804247228852a3"
  key-name        = module.keypair.public-key-id
  asg-sg          = module.securitygroup.asg-sg
  nexus-ip-stg    = module.nexus.nexus_pub_ip
  nr-key-stg      = "4243993"
  nr-acc-id-stg   = "NRAK-HPT5OJANIT515S5M7XMTIRUERKX"
  nr-region-stg   = "EU"
  vpc-zone-id-stg = [module.vpc.privatesub1, module.vpc.privatesub2]
  asg-stg-name    = "${local.name}-stage-asg"
  tg-arn          = module.stage-lb.stage-tg-arn
}

# Include the ASG for production environment
module "asg-prd" {
  source          = "./modules/prod-autoscaling"
  ami-prd         = "ami-05f804247228852a3"
  key-name        = module.keypair.public-key-id
  asg-sg          = module.securitygroup.asg-sg
  nexus-ip-prd    = module.nexus.nexus_pub_ip
  nr-key-prd      = "4243993"
  nr-acc-id-prd   = "NRAK-HPT5OJANIT515S5M7XMTIRUERKX"
  nr-region-prd   = "EU"
  vpc-zone-id-prd = [module.vpc.privatesub1, module.vpc.privatesub2]
  asg-prd-name    = "${local.name}-prod-alb"
  tg-arn          = module.asg-prd.prod-tg-arn
}

module "bastion" {
  source      = "./modules/bastion"
  ami_redhat  = "ami-05f804247228852a3"
  bastion_sg  = module.securitygroup.bastion-sg
  subnet_id   = module.vpc.publicsub2
  keyname     = module.keypair.public-key-id
  private_key = module.keypair.private-key-id
  tag_bastion = "${local.name}-bastion"
}

module "ansible" {
  source                   = "./module/Ansible"
  ami-redhat               = "ami-05f804247228852a3"
  ansible-sg               = module.securitygroup.ansible-sg
  key-name                 = module.keypair.public-key-id
  subnet-id                = module.vpc.privatesub1
  name                     = "${local.name}-ansible"
  staging-MyPlaybook       = "${path.root}/module/ansible/stage-playbook.yaml"
  prod-MyPlaybook          = "${path.root}/module/ansible/prod-playbook.yaml"
  staging-discovery-script = "${path.root}/module/ansible/stage-inventory-bash-script.sh"
  prod-discovery-script    = "${path.root}/module/ansible/prod-inventory-bash-script.sh"
  private_key              = module.keypair.private-key-id
  nexus-ip                 = module.nexus.nexus_pub_ip
  nr-key                   = "4243993"
  nr-acc-id                = "NRAK-HPT5OJANIT515S5M7XMTIRUERKX"
  nr-region                = "EU"
}

module "jenkins" {
  source       = "./module/jenkins"
  ami-redhat   = "ami-05f804247228852a3"
  subnet-id    = module.vpc.privatesub1
  jenkins-sg   = module.securitygroup.jenkins-sg
  key-name     = module.keypair.public-key-id
  jenkins-name = "${local.name}-jenkins"
  nexus-ip     = module.nexus.nexus_pub_ip
  cert-arn     = data.aws_acm_certificate.cert.arn
  subnet-elb   = [module.vpc.publicsub1, module.vpc.publicsub2]
  nr-key       = "4243993"
  nr-acc-id    = "NRAK-HPT5OJANIT515S5M7XMTIRUERKX"
  nr-region    = "EU"
}

module "nexus" {
  source      = "./module/nexus"
  ami         = "ami-05f804247228852a3"
  keypair     = module.keypair.public-key-id
  nexus-sg    = module.securitygroup.nexus-sg
  subnet_id   = module.vpc.publicsub1
  name        = "${local.name}-nexus"
  elb-subnets = [module.vpc.publicsub1, module.vpc.publicsub2]
  cert-arn    = data.aws_acm_certificate.cert.arn
  nr-key      = "4243993"
  nr-acc-id   = "NRAK-HPT5OJANIT515S5M7XMTIRUERKX"
  nr-region   = "EU"
}

module "prod-alb" {
  source          = "./module/prod-alb"
  vpc_id          = module.vpc.vpc_id
  prod-sg         = [module.securitygroup.asg-sg]
  prod-subnet     = [module.vpc.publicsub1, module.vpc.publicsub2, module.vpc.publicsub3]
  certificate_arn = data.aws_acm_certificate.cert.arn
  prod-alb-name   = "${local.name}-prod-alb"
}

module "stage-alb" {
  source          = "./module/stage-alb"
  vpc_id          = module.vpc.vpc_id
  stage-sg        = [module.securitygroup.asg-sg]
  stage-subnet    = [module.vpc.publicsub1, module.vpc.publicsub2, module.vpc.publicsub3]
  certificate_arn = data.aws_acm_certificate.cert.arn
  stage-alb-name  = "${local.name}-stage-alb"
}

module "route53" {
  source                = "./module/route53"
  domain_name           = "dv-gidideals.co.uk"
  jenkins_domain_name   = "jenkins.dv-gidideals.co.uk"
  jenkins_lb_dns_name   = module.jenkins.jenkins_dns_name
  jenkins_lb_zone_id    = module.jenkins.jenkins_zone_id
  nexus_domain_name     = "nexus.dv-gidideals.co.uk"
  nexus_lb_dns_name     = module.nexus.nexus_dns_name
  nexus_lb_zone_id      = module.nexus.nexus_zone_id
  sonarqube_domain_name = "sonarqube.dv-gidideals.co.uk"
  sonarqube_lb_dns_name = module.sonarqube.sonarqube_dns_name
  sonarqube_lb_zone_id  = module.sonarqube.sonarqube_zone_id
  prod_domain_name      = "prod.dv-gidideals.co.uk"
  prod_lb_dns_name      = module.prod-lb.prod-lb-dns
  prod_lb_zone_id       = module.prod-lb.prod-lb-zoneid
  stage_domain_name     = "stage.dv-gidideals.co.uk"
  stage_lb_dns_name     = module.stage-lb.stage-lb-dns
  stage_lb_zone_id      = module.stage-lb.stage-lb-zoneid
}

module "rds-database" {
  source                  = "./module/rds-database"
  db_subnet_grp           = "db-subnetgroup"
  subnet                  = [module.vpc.privatesub1, module.vpc.privatesub2, module.vpc.privatesub3]
  security_group_mysql_sg = module.securitygroup.rds-sg
  db_name                 = "petclinic"
  db_username             = data.vault_generic_secret.vault-secret.data["username"]
  db_password             = data.vault_generic_secret.vault-secret.data["password"]
  tag-db-subnet           = "${local.name}-db-subnet"
}

data "vault_generic_secret" "secret" {
  path = "secrets/database"
}