# https://github.com/terraform-linters/tflint
# this is the default TFLINT config file that will be used when TFLINT is
# executed. Jenkins will use this configuration when doing the static analysis
# check. Additionally, you can include a .tflint.hcl in the modules directory
# itself for more refined testing. Jenkins will look for for a tflint.hcl for
# each module, if one does not exist, the below config will be used.

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

config {
  call_module_type = "none"
  force            = false
}

rule "terraform_deprecated_interpolation" {
  enabled = true
}

rule "terraform_naming_convention" {
  enabled = true
  format  = "snake_case"
}

rule "terraform_required_version" {
  enabled = true
}

rule "terraform_required_providers" {
  enabled = false
}

rule "terraform_typed_variables" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = false
}

rule "terraform_documented_outputs" {
  enabled = false
}
