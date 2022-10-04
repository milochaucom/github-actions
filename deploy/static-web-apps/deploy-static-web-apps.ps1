<#
  .SYNOPSIS
  This script deploys a Static Web application
  .PARAMETER projectsToPublishPath
  The path of the projects to publish
  .PARAMETER resourceGroupName
  The resource group name
  .PARAMETER applicationName
  The application name
  .PARAMETER npmBuildScript
  The npm script to build
  .PARAMETER relativeOutputPath
  The path of the built application, relative to the 'projectsToPublishPath'
  .PARAMETER distSource
  The source of the dist files
  .PARAMETER verbosity
  The verbosity level
#>

[CmdletBinding()]
Param(
  [parameter(Mandatory = $true)]
  [string]$projectsToPublishPath,

  [parameter(Mandatory = $true)]
  [string]$resourceGroupName,

  [parameter(Mandatory = $true)]
  [string]$applicationName,

  [parameter(Mandatory = $true)]
  [string]$npmBuildScript,

  [parameter(Mandatory = $true)]
  [string]$relativeOutputPath,
  
  [parameter(Mandatory = $true)]
  [ValidateSet('build', 'artifact')]
  [string]$distSource,

  [parameter(Mandatory = $true)]
  [ValidateSet('minimal', 'normal', 'detailed')]
  [string]$verbosity
)

Write-Output "Projects to publish path is: $projectsToPublishPath"
Write-Output "Resource group name is: $resourceGroupName"
Write-Output "Application name is: $applicationName"
Write-Output "npm build script is: $npmBuildScript"
Write-Output "Dist source is: $distSource"
Write-Output "Verbosity is: $verbosity"

Write-Output '=========='
Write-Output 'Moving into projects to publish path...'
Set-Location $projectsToPublishPath

Write-Output '=========='
Write-Output 'Determining source source...'
if ($distSource -eq 'build') {
  Write-Output "Source has to be built. App location will be '$projectsToPublishPath$relativeOutputPath'"
  Write-Output "::set-output name=app_location::$projectsToPublishPath$relativeOutputPath"

  Write-Output '=========='
  Write-Output 'Install npm packages...'
  npm ci
  
  Write-Output '=========='
  Write-Output 'Build application...'
  npm run $npmBuildScript
} else {
  Write-Output "Source has already been built."

  Write-Output '=========='
  Write-Output 'Extracting archive...'
  $compressedFilePath = "./output-compressed/app.zip"
  New-Item -Path ".$relativeOutputPath" -ItemType Directory | Out-Null
  [System.IO.Compression.ZipFile]::ExtractToDirectory($compressedFilePath, ".$relativeOutputPath")

  Write-Output "Projects to publish path: $(Resolve-Path $projectsToPublishPath)"
  Write-Output "Compressed file path: $(Resolve-Path $compressedFilePath)"
  Write-Output "Extract output path: $(Resolve-Path ".$relativeOutputPath")"
  Write-Output "App location: $(Resolve-Path $projectsToPublishPath$relativeOutputPath)"

  Write-Output "Get-ChildItem - ." | Select-Object { $_.Name }
  Write-Output "Get-ChildItem - .$relativeOutputPath" | Select-Object { $_.Name }
  Get-ChildItem -Path "."
  Get-ChildItem -Path ".$relativeOutputPath"

  Write-Output "Source has already been extracted. App location is '$projectsToPublishPath$relativeOutputPath'"
  Write-Output "::set-output name=app_location::$projectsToPublishPath$relativeOutputPath"
}

Write-Output '=========='
Write-Output 'Detach Static Web Apps application'
Remove-AzStaticWebAppAttachedRepository -ResourceGroupName $resourceGroupName -Name $applicationName

Write-Output '=========='
Write-Output 'Determine Static Web Apps deployment token'
$swaSecrets = Get-AzStaticWebAppSecret -ResourceGroupName $resourceGroupName -Name $applicationName
$token = $swaSecrets.Property['apiKey']
Write-Output "::set-output name=token::$token"
Write-Output "Deployment token found ($($token.Length) characters)."

Write-Output '=========='
