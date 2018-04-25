function Get-JiraWorkflow
{
    <#
    .Synopsis

    .DESCRIPTION
       Get workflow from Jira
    .EXAMPLE
       Get-JiraWorkflow -WorkFlowName 'My New WorkFlow'

       Returns a single workflow
    .EXAMPLE
        Get-JiraWorkflow

        Lists all workflows
    .INPUTS
    .OUTPUTS
    #>
    [CmdletBinding()]
    param(
        # Workflow name
        [Parameter(Mandatory = $false)]
        [string]
        $WorkflowName,

        # Credentials to use to connect to JIRA.
        # If not specified, this function will use anonymous access.
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]
        $Credential
    )

    begin
    {
        $server = Get-JiraConfigServer -ConfigFile $ConfigFile -ErrorAction Stop
        $restUri = "$server/rest/api/2/workflow"
    }

    process
    {
        If ($WorkflowName)
        {
            [uri]$restUri = '{0}?workflowName={1}' -f $restUri, $WorkflowName
        }
        Write-Verbose "rest URI: [$restUri]"
        $results = Invoke-JiraMethod -Method GET -URI $restUri -Credential $Credential
        If ($results)
        {
            ConvertTo-JiraWorkflow -InputObject $results
        }
        else
        {
            Write-Error "Unable to locate Jira Workflow"
        }
    }
    end
    {
    }
}
