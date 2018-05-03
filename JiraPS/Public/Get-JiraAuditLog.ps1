function Get-JiraAuditLog
{
    [CmdletBinding()]
    param(

        # Maximum number of returned results (if is limit is <= 0 or > 1000, it will be set do default value: 1000)
        [Parameter()]
        [int]
        $Limit,

        # Text query; each record that will be returned must contain the provided text in one of its fields
        [Parameter()]
        [string]
        $Filter,

        [PSCredential]
        $Credential
    )

    begin
    {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"
        $server = Get-JiraConfigServer -ErrorAction Stop
        $resourceURi = "$server/rest/api/2/auditing/record?"
    }

    process
    {
        If($Limit)
        {
            $resourceURi += "&limit=$limit"
        }
        If($Filter)
        {
            $resourceURi += "&Filter=$Filter"
        }
        $parameter = @{
            URI        = $resourceURi
            Method     = "GET"
            Credential = $Credential
        }
        Invoke-JiraMethod @parameter
    }
    end
    {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}
