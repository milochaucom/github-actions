<#
  .SYNOPSIS
  This script releases a workspace as a npm package
  .PARAMETER mainBranch
  The main branch
  .PARAMETER currentBranch
  The current branch
  .PARAMETER npmjsComToken
  The npmjs.com token
  .PARAMETER githubToken
  The GitHub token
  .PARAMETER avoidGithubPrerelease
  Avoid creating GitHub release for prerelease versions
  .PARAMETER generateReleaseNotes
  Generate release notes
#>

Write-Output '=========='
Write-Output 'Get parameters...'

param(
  [parameter(Mandatory = $true)]
  [string]$mainBranch
)
param(
  [parameter(Mandatory = $true)]
  [string]$currentBranch
)
param(
  [parameter(Mandatory = $true)]
  [string]$npmjsComToken
)
param(
  [parameter(Mandatory = $true)]
  [string]$githubToken
)
param(
  [parameter(Mandatory = $true)]
  [bool]$avoidGithubPrerelease
)
param(
  [parameter(Mandatory = $true)]
  [bool]$generateReleaseNotes
)

Write-Output "Main branch is: $mainBranch"
Write-Output "Current branch is: $currentBranch"
Write-Output "npmjs.com token is: $npmjsComToken"
Write-Output "GitHub token is: $githubToken"
Write-Output "Avoid GitHub prerelease is: $avoidGithubPrerelease"
Write-Output "Generate release notes is: $generateReleaseNotes"


Write-Output '=========='
Write-Output 'Get current version...'

$versionFileContent = Get-Content -Path package.json | ConvertFrom-Json
$version = "v" + $versionFileContent.version
Write-Output "Version is: $version"

$exp = '^v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*)(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$'
$match = $version -match $exp
Write-Output "Prerelease match is: $match"


Write-Output '=========='
Write-Output 'Check prerelease if not main branch...'

if ( ($currentBranch -ne $mainBranch) -And ($match -ne $true)) {
  Write-Output 'You can not publish a stable release package if you are not in the main branch'
  exit 1
}

Write-Output '=========='
Write-Output 'Install packages...'
npm ci

Write-Output '=========='
Write-Output 'Build application...'
npm run build

Write-Output '=========='
Write-Output 'Publish projects to npmjs.com...'
if ($npmjsComToken.length -gt 0) {
  Write-Output 'Token for npmjs.com is found.'
  npm set registry "https://registry.npmjs.org"
  npm set //registry.npmjs.org/:_authToken $npmjsComToken
  npm publish
}

Write-Output '=========='
Write-Output 'Publish projects to GitHub Packages...'
npm set registry "https://npm.pkg.github.com"
npm set //npm.pkg.github.com/:_authToken $githubToken
npm publish

Write-Output '=========='
Write-Output 'Create GitHub Release...'
if ($match -And $avoidGithubPrerelease) {
  Write-Output 'No release must be created.'
  return
}

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Accept", "application/vnd.github.v3+json")
$headers.Add("Authorization", "token $githubToken")

Write-Output 'Checking if release notes must be included...'
$releaseNote = '...'
if ($generateReleaseNotes) {
  Write-Output 'Release note must be included.'

  $response = Invoke-RestMethod "https://api.github.com/repos/$Env:GITHUB_REPOSITORY/releases/latest" -Method 'GET' -Headers $headers -SkipHttpErrorCheck
  if ($response.tag_name) {
    $lastRelease = $response.tag_name
    Write-Output "Latest release is $($lastRelease)."

    $headers.Add("Content-Type", "application/json")
    $body = [PSCustomObject]@{
      tag_name = "$version";
      previous_tag_name = $lastRelease;
    } | ConvertTo-Json

    $response = Invoke-RestMethod "https://api.github.com/repos/$Env:GITHUB_REPOSITORY/releases/generate-notes" -Method 'POST' -Headers $headers -Body $body
    $releaseNote = $response.body
    
    Write-Output 'Release note has been generated.'
  } else {
    Write-Output 'No release has been found, release note can''t be generated.'
  }
} else {
  Write-Output 'Release note is read from CHANGELOG.md'
  
  $releaseNote = Get-Content 'CHANGELOG.md' | Out-String
  
  Write-Output 'Release note has been read.'
}

Write-Debug $releaseNote

Write-Output 'Creating release...'
if ($match -eq $false) {
  Write-Output 'A stable release must be created.'

  $body = [PSCustomObject]@{
    tag_name = "$version";
    name = "Version $version";
    body = $releaseNote;
    draft = $true;
  } | ConvertTo-Json

  Invoke-RestMethod "https://api.github.com/repos/$Env:GITHUB_REPOSITORY/releases" -Method 'POST' -Headers $headers -Body $body

  Write-Output 'Stable release has been created.'
} elseif ($avoidGithubPrerelease -eq $false) {
  Write-Output 'A prerelease must be created.'

  $body = [PSCustomObject]@{
    tag_name = "$version";
    name = "Version $version";
    body = $releaseNote;
    draft = $true;
    prerelease = $true;
  } | ConvertTo-Json

  Invoke-RestMethod "https://api.github.com/repos/$Env:GITHUB_REPOSITORY/releases" -Method 'POST' -Headers $headers -Body $body

  Write-Output 'Prerelease has been created.'
} else {
  Write-Output 'No release has been created!'
}

Write-Output "=========="