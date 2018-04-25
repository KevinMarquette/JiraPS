$Script:ModuleName = 'JiraPS'
. $psscriptroot\BuildTasks\InvokeBuildInit.ps1

task Default Build, Test, UpdateSource
task Build Copy, BuildModule, BuildManifest
task Helpify GenerateMarkdown, GenerateHelp
task Test Build, ImportModule, FullTests

Write-Host 'Import common tasks'
Get-ChildItem -Path $buildroot\BuildTasks\*.Task.ps1 |
    ForEach-Object {Write-Host $_.FullName;. $_.FullName}


