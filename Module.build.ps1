$Script:ModuleName = 'JiraPS'
$config = Get-Module "Configuration" -ListAvailable
if (-not $config)
{
    Install-Module -Name "Configuration" -Force -RequiredVersion "1.3.1"
}
. $psscriptroot\BuildTasks\InvokeBuildInit.ps1

task Default Build, Test, UpdateSource
task Build Copy, BuildModule, BuildManifest
task Helpify GenerateMarkdown, GenerateHelp
task Test Build, ImportModule, FullTests

Write-Host 'Import common tasks'
Get-ChildItem -Path $buildroot\BuildTasks\*.Task.ps1 |
    ForEach-Object {Write-Host $_.FullName;. $_.FullName}


