function Get-JiraWorkflowScheme
{
    <#
    .Synopsis

    .DESCRIPTION
       Get Jira workflow scheme
    .EXAMPLE
       Get-JiraWorkflowScheme -Name 'My Scheme'

       Returns a single scheme object
    .EXAMPLE
        Get-JiraWorkflowScheme -ID 95001

        Returns a single scheme object
    .EXAMPLE
        Get-JiraWorkflowScheme

        Lists all workflows
    .INPUTS
    .OUTPUTS
    #>
    [CmdletBinding()]
    param(
        # Scheme ID
        [Parameter(Mandatory = $true)]
        [int]
        $ID,

        # Credentials to use to connect to Jira
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]
        $Credential
    )

    begin
    {
        $server = Get-JiraConfigServer -ErrorAction Stop
        $restUrl = "$server/rest/api/2/workflowscheme/$ID"
    }

    process
    {
        Write-Verbose "rest URL: [$restUrl]"
        $results = Invoke-JiraMethod -Method GET -URI $restUrl -Credential $Credential
        If ($results)
        {
            ConvertTo-JiraWorkflowScheme -InputObject $results
        }
        else
        {
            Write-Verbose "JIRA returned no results."
        }
    }
    end
    {
    }
}
