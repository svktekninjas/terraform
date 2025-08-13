module "component" {
  source                  = "./modules/component"
  namespace               = var.namespace
  dockerconfigjson_base64 = var.dockerconfigjson_base64
}

module "spring_boot_admin" {
  source                  = "./modules/spring_boot_admin"
  namespace               = var.namespace
  image                   = var.spring_boot_admin_image
  depends_on = [module.component]
}

module "naming_server" {
  source                  = "./modules/naming_server"
  namespace               = var.namespace
  image                   = var.naming_server_image
  depends_on = [module.component]
}

module "apigateway_app" {
  source                  = "./modules/apigateway_app"
  namespace               = var.namespace
  image                   = var.naming_server_image
  depends_on = [module.component]
}

module "common_excel_service" {
  source                  = "./modules/common_excel_service"
  namespace               = var.namespace
  image                   = var.naming_server_image
  depends_on = [module.component]
}

module "spring_cloud_config_service" {
  source                  = "./modules/spring_cloud_config_service"
  namespace               = var.namespace
  image                   = var.naming_server_image
  depends_on = [module.component]
}

module "bench_profile_service" {
  source                  = "./modules/bench_profile_service"
  namespace               = var.namespace
  image                   = var.naming_server_image
  depends_on = [module.component]
}

module "daily_submissions_service" {
  source                  = "./modules/daily_submissions_service"
  namespace               = var.namespace
  image                   = var.naming_server_image
  depends_on = [module.component]
}

module "interviews_service" {
  source                  = "./modules/interviews_service"
  namespace               = var.namespace
  image                   = var.naming_server_image
  depends_on = [module.component]
}

module "placements_service" {
  source                  = "./modules/placements_service"
  namespace               = var.namespace
  image                   = var.naming_server_image
  depends_on = [module.component]
}

module "frontend_service" {
  source                  = "./modules/frontend_service"
  namespace               = var.namespace
  image                   = var.naming_server_image
  depends_on = [module.component]
}
