function Add-JiraRoleMember
{
    [CmdletBinding()]
    param(

        # Role name
        [Parameter(Mandatory)]
        [string]
        $Role,

        # Jira project key
        [Parameter(Mandatory)]
        [String[]]
        $Project,

        # Group name to add to role
        [Parameter()]
        [Alias('GroupName')]
        [Object[]]
        $Group,

        # Username to add to role
        [Parameter()]
        [Object[]]
        $UserName,

        [PSCredential]
        $Credential
    )

    begin
    {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"

        $server = Get-JiraConfigServer -ErrorAction Stop
        $resourceURi = "$server/rest/api/latest/project/{0}/role/{1}"
    }

    process
    {
        Foreach ($p in $Project)
        {
            $body = @{}
            $roleID = Get-JiraRole -Project $p -Credential $Credential |
                Where-Object {$PSItem.Role -eq $Role} |
                Select-Object -ExpandProperty RoleID
            If ($UserName)
            {
                $body.user = $UserName
            }
            If ($Group)
            {
                $body.group = $Group
            }
            $parameter = @{
                URI        = $resourceURi -f $p, $roleID
                Method     = "POST"
                Body       = (ConvertTo-Json -inputobject $body -Depth 7)
                Credential = $Credential
            }
            $result = Invoke-JiraMethod @parameter
            Write-Output (ConvertTo-JiraRole -InputObject $result)
        }
    }

    end
    {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}
