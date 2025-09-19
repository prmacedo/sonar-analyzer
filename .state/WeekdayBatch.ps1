$ErrorActionPreference = 'Stop'
$workDir = 'D:\Projetos\Mestrado\sonar-analyzer'
$runner = 'run-multi.bat'
$scheduler = Join-Path -Path $workDir -ChildPath 'scheduler_run.ps1'
if (-not (Test-Path -Path $scheduler -PathType Leaf)) { throw "Helper not found: $scheduler" }
& $scheduler -Runner $runner -WorkingDirectory $workDir
