param(
  [Parameter(Mandatory = $true)]
  [string]$ProductId
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false

function Set-FinalizedOutput([bool]$finalized) {
  if ($env:GITHUB_OUTPUT) {
    $value = $finalized.ToString().ToLowerInvariant()
    Add-Content -Path $env:GITHUB_OUTPUT -Value "finalized=$value"
  }
}

function Set-ReadyOutput([bool]$ready) {
  if ($env:GITHUB_OUTPUT) {
    $value = $ready.ToString().ToLowerInvariant()
    Add-Content -Path $env:GITHUB_OUTPUT -Value "ready=$value"
  }
}

function Invoke-StoreCommand([string[]]$Arguments) {
  $output = @(& msstore @Arguments 2>&1)
  $exitCode = $LASTEXITCODE
  $output | ForEach-Object { Write-Host $_.ToString() }

  return @{
    ExitCode = $exitCode
    Output = $output
  }
}

function ConvertFrom-StoreJson($Output, [string]$Description) {
  $text = ($Output | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
  $jsonStart = $text.IndexOf("{")
  $jsonEnd = $text.LastIndexOf("}")

  if ($jsonStart -lt 0 -or $jsonEnd -le $jsonStart) {
    throw "Microsoft Store CLI returned no $Description JSON."
  }

  return $text.Substring($jsonStart, $jsonEnd - $jsonStart + 1) |
    ConvertFrom-Json
}

Set-FinalizedOutput $false
Set-ReadyOutput $false
$pendingSubmissionFailed = $false

$pollResult = Invoke-StoreCommand @(
  "submission", "poll", $ProductId, "--verbose"
)

if ($pollResult.ExitCode -ne 0) {
  $pollText = ($pollResult.Output | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
  $failedStatuses = @(
    "CommitFailed",
    "PreProcessingFailed",
    "CertificationFailed",
    "ReleaseFailed",
    "PublishFailed",
    "FAILED"
  )
  $knownFailure = $failedStatuses | Where-Object {
    $pollText -match [regex]::Escape($_)
  }

  if ($knownFailure) {
    $pendingSubmissionFailed = $true
    Write-Warning "Existing Microsoft Store submission is failed; attempting to remove it before publishing."
  } else {
    Write-Error "Could not wait for the existing Microsoft Store submission to finish."
    exit $pollResult.ExitCode
  }
}

$appResult = Invoke-StoreCommand @(
  "apps", "get", $ProductId, "--verbose"
)

if ($appResult.ExitCode -ne 0) {
  Write-Error "Could not retrieve the Microsoft Store application."
  exit $appResult.ExitCode
}

try {
  $application = ConvertFrom-StoreJson $appResult.Output "application"
} catch {
  Write-Error $_.Exception.Message
  exit 1
}

$pendingSubmissionId = $application.PendingApplicationSubmission.Id
if ($pendingSubmissionId) {
  if (-not $pendingSubmissionFailed) {
    Write-Host "::notice::Microsoft Store submission $pendingSubmissionId is still being processed. Skipping this publish instead of creating a conflicting submission."
    exit 0
  }

  $deleteResult = Invoke-StoreCommand @(
    "submission", "delete", $ProductId, "--no-confirm", "--verbose"
  )
  if ($deleteResult.ExitCode -ne 0) {
    Write-Warning "The failed Microsoft Store submission could not be deleted yet. Skipping this publish."
    exit 0
  }

  $appResult = Invoke-StoreCommand @(
    "apps", "get", $ProductId, "--verbose"
  )
  if ($appResult.ExitCode -ne 0) {
    Write-Error "Could not verify the Microsoft Store application after deleting the failed submission."
    exit $appResult.ExitCode
  }

  try {
    $application = ConvertFrom-StoreJson $appResult.Output "application"
  } catch {
    Write-Error $_.Exception.Message
    exit 1
  }

  if ($application.PendingApplicationSubmission.Id) {
    Write-Warning "Microsoft Store still reports a pending submission after deletion. Skipping this publish."
    exit 0
  }
}

$submissionId = $application.LastPublishedApplicationSubmission.Id
if (-not $submissionId) {
  Set-FinalizedOutput $true
  Set-ReadyOutput $true
  Write-Host "No published Microsoft Store submission exists yet; there is no rollout to finalize."
  exit 0
}

$getResult = Invoke-StoreCommand @(
  "submission", "rollout", "get", $ProductId,
  "--submissionId", $submissionId, "--verbose"
)

if ($getResult.ExitCode -ne 0) {
  Write-Error "Could not retrieve the Microsoft Store package rollout."
  exit $getResult.ExitCode
}

try {
  $rollout = ConvertFrom-StoreJson $getResult.Output "rollout"
} catch {
  Write-Error $_.Exception.Message
  exit 1
}

if (
  -not $rollout.IsPackageRollout -or
  $rollout.PackageRolloutStatus -eq "PackageRolloutComplete"
) {
  Set-FinalizedOutput $true
  Set-ReadyOutput $true
  Write-Host "No active Microsoft Store package rollout remains."
  exit 0
}

$finalizeResult = Invoke-StoreCommand @(
  "submission", "rollout", "finalize", $ProductId,
  "--submissionId", $submissionId, "--verbose"
)

if ($finalizeResult.ExitCode -ne 0) {
  Write-Error "Microsoft Store package rollout finalization failed."
  exit $finalizeResult.ExitCode
}

Set-FinalizedOutput $true
Set-ReadyOutput $true
Write-Host "Finalized the active Microsoft Store package rollout."
exit 0
