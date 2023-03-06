<#
  .SYNOPSIS
  This script builds and tests Terraform modules
  .PARAMETER solutionPath
  The path to the solution file, with functions to deploy
  .PARAMETER publishPathFilter
  The path of the files to publish, as a filter to be tested to determine the files to add in the artifact
  .PARAMETER verbosity
  The verbosity level
#>

[CmdletBinding()]
Param(
  [parameter(Mandatory = $true)]
  [string]$solutionPath, # Typically './src/proto-api/Milochau.Proto.Functions.sln'

  [parameter(Mandatory = $true)]
  [string]$publishPathFilter, # Typically '*/bin/Release/net7.0/linux-x64/publish/bootstrap'
  
  [parameter(Mandatory = $true)]
  [ValidateSet('minimal', 'normal', 'detailed')]
  [string]$verbosity
)

Write-Output "Solution path is: $solutionPath"
Write-Output "Publish path filter is: $publishPathFilter"
Write-Output "Verbosity is: $verbosity"

Write-Output '=========='

$sw = [Diagnostics.Stopwatch]::StartNew()
$image = "public.ecr.aws/sam/build-dotnet7:latest-x86_64"
$dir = (Get-Location).Path

Write-Output "Pull Docker image, used to build functions"
docker pull $image -q

docker run --rm -v "$($dir):/src" -w /src $image dotnet publish "$solutionPath" -c Release -f net7.0 -r linux-x64 --sc true -p:BuildSource=AwsCmd /p:GenerateRuntimeConfigurationFiles=true /p:StripSymbols=true
if (!$?) {
  Write-Output "::error title=Build failed::Build failed"
  throw 1
}

Write-Output '=========='

Write-Output "Finding the files to publish in the artifact..."

$publishPathFilterLinux = $publishPathFilter.Replace("\", "/")
$publishPathFilterWindows = $publishPathFilter.Replace("/", "\")
$solutionDirectoryPath = (Get-ChildItem $solutionPath).Directory.FullName
$childItems = Get-ChildItem -Path $solutionDirectoryPath -Recurse -Include 'bootstrap'

if (Test-Path "./output") {
  Remove-Item -LiteralPath "./output" -Force -Recurse
}
if (Test-Path "./output-compressed") {
  Remove-Item -LiteralPath "./output-compressed" -Force -Recurse
}
New-Item -Path "./output" -ItemType Directory | Out-Null
New-Item -Path "./output-compressed" -ItemType Directory | Out-Null

Write-Output '=========='

$childItemsCount = $childItems.Count
Write-Output "Items found: $childItemsCount"

foreach ($childItem in $childItems) {
  $directoryRelativePath = $childItem.Directory.FullName | Resolve-Path -Relative
  $fileRelativePath = $childItem.FullName | Resolve-Path -Relative

  if ($fileRelativePath -inotlike $publishPathFilterLinux -and $fileRelativePath -inotlike $publishPathFilterWindows) {
    Write-Output "[$fileRelativePath] Not treated."
    continue
  }

  Write-Output "[$fileRelativePath] Copying file to output..."
  $directoryDestinationPath = Join-Path "$PWD/output" "$directoryRelativePath"
  $destinationPath = Join-Path $directoryDestinationPath $childItem.Name
  if (-not (Test-Path $directoryDestinationPath)) {
    New-Item -Path $directoryDestinationPath -ItemType Directory | Out-Null
  }
  Copy-Item -Path $childItem -Destination $destinationPath
  Write-Output "[$fileRelativePath] File copied to output."

  Write-Output "[$fileRelativePath] Creating compressed file..."
  $compressedFilePath = "$destinationPath.zip"
  [System.IO.Compression.ZipFile]::CreateFromDirectory($directoryDestinationPath, $compressedFilePath)
  Write-Output "[$fileRelativePath] Compressed file created."

  Write-Output "-----"
}

Write-Output '=========='

$sw.Stop()
Write-Output "Job duration: $($sw.Elapsed.ToString("c"))"
