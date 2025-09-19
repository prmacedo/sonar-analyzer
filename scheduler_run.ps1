[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$Runner,
    [Parameter(Mandatory=$true)]
    [string]$WorkingDirectory
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -Path $WorkingDirectory -PathType Container)) {
    throw "Working directory not found: $WorkingDirectory"
}

$runnerPath = Join-Path -Path $WorkingDirectory -ChildPath $Runner
if (-not (Test-Path -Path $runnerPath -PathType Leaf)) {
    throw "Runner not found: $runnerPath"
}

Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', """$runnerPath""" -WorkingDirectory $WorkingDirectory -WindowStyle Hidden -Wait
