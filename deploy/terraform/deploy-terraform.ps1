<#
  .SYNOPSIS
  This script deploy a Terraform module
  .PARAMETER modulePath
  The path to the Terraform module to deploy
  .PARAMETER workspaceName
  The name of the Terraform workspace
  .PARAMETER verbosity
  The verbosity level
#>

[CmdletBinding()]
Param(
  [parameter(Mandatory = $true)]
  [string]$modulePath,

  [parameter(Mandatory = $true)]
  [string]$workspaceName,
  
  [parameter(Mandatory = $true)]
  [ValidateSet('minimal', 'normal', 'detailed')]
  [string]$verbosity
)

Write-Output "Modules path is: $modulesPath"
Write-Output "Workspace name is: $workspaceName"
Write-Output "Verbosity is: $verbosity"

Write-Output '=========='

$sw = [Diagnostics.Stopwatch]::StartNew()

Write-Output "Starting..."

Write-Output "Terraform initialisation..."
terraform init -input=false -upgrade -no-color
if (!$?) {
    Write-Output "::error title=Terraform failed::Terraform initialization failed"
    throw 1
}

Write-Output "Terraform workspace selection..."
terraform workspace select $workspaceName -no-color
if (!$?) {
  Write-Output "::error title=Terraform failed::Terraform workspace selection failed"
  throw 1
}

Write-Output "Terraform format..."
terraform fmt -check -recursive -no-color
if (!$?) {
    Write-Output "::error title=Terraform failed::Terraform format failed"
    throw 1
}

Write-Output "Terraform validation..."
terraform validate -json -no-color
if (!$?) {
    Write-Output "::error title=Terraform failed::Terraform validation failed"
    throw 1
}

Write-Output "Terraform plan..."
$planResult = terraform plan -var-file="hosts/$workspaceName.tfvars" -input=false -json -no-color
if (!$?) {
    Write-Output "::error title=Terraform failed::Terraform plan failed"
    throw 1
}

$planResultJson = $planResult | ConvertFrom-Json

Write-Output "  Add: $($planResultJson.changes.add.Count)"
Write-Output "  Change: $($planResultJson.changes.change.Count)"
Write-Output "  Remove: $($planResultJson.changes.remove.Count)"
 
Write-Output "Terraform apply..."
terraform apply -var-file="hosts/$workspaceName.tfvars" -input=false -json -auto-approve -no-color
if (!$?) {
    Write-Output "::error title=Terraform failed::Terraform apply failed"
    throw 1
}

Write-Output "Terraform deployment done."

Write-Output '=========='

$sw.Stop()
Write-Output "Job duration: $($sw.Elapsed.ToString("c"))"
