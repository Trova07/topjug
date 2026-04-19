terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  # 팀 공유 시 S3 backend로 교체 권장
  # backend "s3" {
  #   bucket = "topjug-tfstate"
  #   key    = "prod/terraform.tfstate"
  #   region = "ap-northeast-2"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "topjug"
      ManagedBy = "terraform"
    }
  }
}

# CloudFront ACM 인증서는 반드시 us-east-1 리전 필요
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project   = "topjug"
      ManagedBy = "terraform"
    }
  }
}

# ── 모듈 호출 ────────────────────────────────────────────

module "networking" {
  source = "./modules/networking"

  project  = var.project
  vpc_cidr = var.vpc_cidr
  az_list  = var.az_list
}

module "ecr" {
  source = "./modules/ecr"

  project = var.project
}

module "loadbalancer" {
  source = "./modules/loadbalancer"

  project        = var.project
  vpc_id         = module.networking.vpc_id
  public_subnets = module.networking.public_subnet_ids
  alb_sg_id      = module.networking.alb_sg_id
}

module "database" {
  source = "./modules/database"

  project        = var.project
  public_subnets = module.networking.public_subnet_ids
  rds_sg_id      = module.networking.rds_sg_id
  db_name        = var.db_name
  db_username    = var.db_username
  db_password    = var.db_password
  db_instance    = var.db_instance_class
}

module "compute" {
  source = "./modules/compute"

  project              = var.project
  vpc_id               = module.networking.vpc_id
  public_subnets       = module.networking.public_subnet_ids
  ecs_sg_id            = module.networking.ecs_sg_id
  alb_target_group_arn = module.loadbalancer.target_group_arn
  ecr_api_url          = module.ecr.api_repository_url
  db_host              = module.database.db_host
  db_port              = module.database.db_port
  db_name              = var.db_name
  db_username          = var.db_username
  db_password          = var.db_password
  api_cpu              = var.api_cpu
  api_memory           = var.api_memory
  api_desired_count    = var.api_desired_count
}

module "storage" {
  source = "./modules/storage"

  project = var.project
}

module "cdn" {
  source = "./modules/cdn"

  providers = {
    aws = aws.us_east_1
  }

  project          = var.project
  s3_bucket_id     = module.storage.bucket_id
  s3_bucket_domain = module.storage.bucket_regional_domain
  alb_dns_name     = module.loadbalancer.alb_dns_name
}
