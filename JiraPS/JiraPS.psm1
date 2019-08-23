[CmdletBinding()]
param()
$Script:PSModuleRoot = $PSScriptRoot
Write-Verbose -Message "This file is replaced in the build output, and is only used for debugging."
Write-Verbose -Message $PSScriptRoot
# Gather all files
$PublicFunctions = @( Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue )
$PrivateFunctions = @( Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue )


# Import custom Classes/Objects
try
{
    Add-Type -Path (Join-Path $PSScriptRoot JiraPS.Types.cs) -ReferencedAssemblies Microsoft.CSharp -ErrorAction Stop
}
catch
{
    if (!(("JiraPS.AssigneeType" -as [Type])))
    {
        $errorMessage = @{
            Category         = "OperationStopped"
            CategoryActivity = "Loading custom classes"
            ErrorId          = 1001
            Message          = "Failed to load module JiraPS. [Could not import JiraPS classes]"
        }
        Write-Error @errorMessage
    }
}

# Dot source the functions
foreach ($file in @($PublicFunctions + $PrivateFunctions)) {
    try {
        . $file.FullName
    }
    catch {
        $exception = ([System.ArgumentException]"Function not found")
        $errorId = "Load.Function"
        $errorCategory = 'ObjectNotFound'
        $errorTarget = $file
        $errorItem = New-Object -TypeName System.Management.Automation.ErrorRecord $exception, $errorId, $errorCategory, $errorTarget
        $errorItem.ErrorDetails = "Failed to import function $($file.BaseName)"
        throw $errorItem
    }
}
Export-ModuleMember -Function $PublicFunctions.BaseName -Alias *
#endregion LoadFunctions
