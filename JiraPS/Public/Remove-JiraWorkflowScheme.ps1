function Remove-JiraWorkflowScheme {
    <#
    .DESCRIPTION
       This function removes an existing workflow scheme.
    .EXAMPLE
       Get-JiraWorkflowScheme -Name 'My Scheme' | Remove-JiraWorkflowScheme
       This example removes the scheme given.
     .INPUTS
        [JiraPS.WorkflowScheme]
    .OUTPUTS
       This Function outputs no results
    .LINK
        Get-JiraWorkflowScheme
    .NOTES
       This function requires either the -Credential parameter to be passed or a persistent JIRA session. See New-JiraSession for more details.  If neither are supplied, this function will run with anonymous access to JIRA.
    #>
    [CmdletBinding(
        ConfirmImpact = 'High',
        SupportsShouldProcess = $true
    )]
    param(
        # Scheme Object to delete.
        [Parameter(
            Position = 0,
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        [Object[]]
        $WorkflowScheme,

        # Credentials to use to connect to Jira
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]
        $Credential,

        # Suppress user confirmation.
        [Switch]
        $Force
    )

    begin {
        $server = Get-JiraConfigServer -ConfigFile $ConfigFile -ErrorAction Stop
        if ($Force) {
            $oldConfirmPreference = $ConfirmPreference
            $ConfirmPreference = 'None'
        }
    }

    process {
        foreach ($scheme in $WorkflowScheme) {
            if ($scheme.PSObject.TypeNames[0] -eq 'JiraPS.WorkflowScheme') {
                $schemeObject = Get-JiraWorkflowScheme -ID $scheme.ID -Credential $Credential
            }
            else {
                Write-Error -Exception "Invalid Scheme Object Provided" -ErrorAction Stop
            }
            If ($schemeObject) {
                $restUrl = "$server/rest/api/2/workflowscheme/$($schemeObject.Id)"
                if ($PSCmdlet.ShouldProcess($schemeObject.Name, "Removing Workflow scheme from JIRA")) {
                    Invoke-JiraMethod -Method Delete -URI $restUrl -Credential $Credential
                }
            }
            else {
                Write-Error "Unable to Locate Scheme Object ID [$ID]"
            }
        }
    }

    end {
        if ($Force) {
            $ConfirmPreference = $oldConfirmPreference
        }
    }
}
