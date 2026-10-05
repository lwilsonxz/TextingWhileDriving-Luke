# Installs the pinned Yarn Spinner for Godot (GDScript) addon into one or more Godot projects.
# The addon is not committed: its licence (YSPL) forbids redistributing unmodified source.
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\setup_yarn_spinner.ps1 [project_dir ...]
#        (defaults to every directory in the repo that contains a project.godot)
$ErrorActionPreference = "Stop"

$YarnRepo = "https://github.com/YarnSpinnerTool/YarnSpinner-Godot-GDScript"
$YarnCommit = "b4852f83ee9295fe03fe6a8c623e8e46e0446d86" # Early Access 3.2 (2026-10-01)

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$Cache = Join-Path $RepoRoot ".cache\yarn-spinner\$YarnCommit"

function Invoke-Git { git @args; if ($LASTEXITCODE -ne 0) { throw "git $args failed" } }

if (-not (Test-Path (Join-Path $Cache "addons\yarn_spinner\plugin.cfg"))) {
	if (Test-Path $Cache) { Remove-Item -Recurse -Force $Cache }
	New-Item -ItemType Directory -Force $Cache | Out-Null
	Invoke-Git -C $Cache init -q
	Invoke-Git -C $Cache remote add origin $YarnRepo
	Invoke-Git -C $Cache fetch -q --depth 1 origin $YarnCommit
	Invoke-Git -C $Cache checkout -q FETCH_HEAD
}

$Projects = $args
if ($Projects.Count -eq 0) {
	$Projects = Get-ChildItem -Path $RepoRoot -Recurse -Filter project.godot |
		Where-Object { $_.FullName -notmatch '\\(\.cache|addons)\\' } |
		ForEach-Object { $_.DirectoryName }
}

foreach ($Project in $Projects) {
	$Addons = Join-Path $Project "addons"
	$Target = Join-Path $Addons "yarn_spinner"
	if (Test-Path $Target) { Remove-Item -Recurse -Force $Target }
	New-Item -ItemType Directory -Force $Addons | Out-Null
	Copy-Item -Recurse (Join-Path $Cache "addons\yarn_spinner") $Target
	Write-Host "Installed Yarn Spinner ($YarnCommit) into $Target"
}
