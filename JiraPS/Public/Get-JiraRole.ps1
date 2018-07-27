function Get-JiraRole
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [String[]]
        $Project,

        # Role ID
        [Parameter()]
        [int]
        $RoleID,

        [PSCredential]
        $Credential
    )

    begin
    {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"
        $server = Get-JiraConfigServer -ErrorAction Stop
        $resourceURi = "$server/rest/api/2/project/{0}/role"
    }

    process
    {
        Foreach($p in $Project)
        {
            If($RoleID)
            {
                $resourceURi = "$resourceURi/$RoleID"
            }
            $parameter = @{
                URI        = $resourceURi -f $p
                Method     = "GET"
                Credential = $Credential
            }
            $result = Invoke-JiraMethod @parameter

            Write-Output ($result | ConvertTo-JiraRole)
        }
    }

    end
    {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}
