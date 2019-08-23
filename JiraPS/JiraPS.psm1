[CmdletBinding()]
param()
$Script:PSModuleRoot = $PSScriptRoot
Write-Verbose -Message "This file is replaced in the build output, and is only used for debugging."
Write-Verbose -Message $PSScriptRoot
# Gather all files
. $PSScriptRoot\originalPSM1Content.ps1
