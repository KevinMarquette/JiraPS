function Set-JiraProject
{
    <#
    .Synopsis
         Modifies project properties in Jira
    .DESCRIPTION
         This function modifies project properties in Jira
    .EXAMPLE
        Set-JiraProject-Key MNP -Name 'My New Project' -ProjectTypeKey Software -Lead 'JDoe' -AssigneType 'PROJECT_LEAD'
    .EXAMPLE
       Set-JiraProject -Key MSP -Name 'My Second Project' -ProjectTypeKey Software -Lead 'JaneDoe' -AvatarID 100005
    .EXAMPLE
       Set-JiraProject -Key MTP -Name 'My Third Project' -ProjectTypeKey Business -Lead 'JDoe' -CategoryId 100002 -PermissionScheme 100003
    .INPUTS
        [JiraPS.Project[]] The JIRA project that should be modified.
    .OUTPUTS
        [JiraPS.Project[]]
    .NOTES

    #>
    [CmdletBinding(
        DefaultParameterSetName = 'ByNamedParameters')]
    param(
        # Project Name or project object obtained from Get-JiraProject.
        [Parameter(Position = 0,
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'ByNamedParameters'
        )]
        [Object[]] $Project,

        # Project Key
        [Parameter(Mandatory = $false,
            ParameterSetName = 'ByNamedParameters')]
        [String] $ProjectKey,

        # Project Type Key
        [Parameter(Mandatory = $false,
            ParameterSetName = 'ByNamedParameters')]
        [String] $ProjectTypeKey,

        # Project Template Key
        [Parameter(Mandatory = $false,
            ParameterSetName = 'ByNamedParameters')]
        [String] $ProjectTemplateKey,

        # Long description of the Project.
        [Parameter(Mandatory = $false,
            ParameterSetName = 'ByNamedParameters')]
        [String] $Description,

        # Username of Project Lead
        [Parameter(Mandatory = $false,
            ParameterSetName = 'ByNamedParameters')]
        [String] $Lead,

        # Assignee Type
        [Parameter(Mandatory = $false)]
        [ValidateSet('PROJECT_LEAD', 'UNASSIGNED')]
        [JiraPS.AssigneeType] $AssigneeType,

        # Avatar ID
        [Parameter(Mandatory = $false,
            ParameterSetName = 'ByNamedParameters')]
        [int] $AvatarId,

        # Issue Security Scheme ID
        [Parameter(Mandatory = $false,
            ParameterSetName = 'ByNamedParameters')]
        [int] $IssueSecurityScheme,

        # Permission Scheme ID
        [Parameter(Mandatory = $false,
            ParameterSetName = 'ByNamedParameters')]
        [int] $PermissionScheme,

        # Notification Scheme ID
        [Parameter(Mandatory = $false,
            ParameterSetName = 'ByNamedParameters')]
        [int] $NotificationScheme,

        # Category ID
        [Parameter(Mandatory = $false,
            ParameterSetName = 'ByNamedParameters')]
        [int] $CategoryId,

        # Credentials to use to connect to JIRA.
        # If not specified, this function will use anonymous access.
        [Parameter(Mandatory = $false,
            ParameterSetName = 'ByNamedParameters')]
        [System.Management.Automation.PSCredential] $Credential
    )

    begin
    {
        $server = Get-JiraConfigServer -ErrorAction Stop
    }
    process
    {
        foreach ($p in $project)
        {
            $projectObj = Get-Jiraproject -Project $p.Key -Credential $Credential
            $projectUrl = "$server/rest/api/2/project/{0}" -f $projectObj.key
            $props = @{}
            # Validate InputObject type
            if ($projectObj.PSObject.TypeNames[0] -ne "JiraPS.Project")
            {
                $message = "Wrong object type provided for Project. Only JiraPS.Project is accepted"
                $exception = New-Object -TypeName System.ArgumentException -ArgumentList $message
                Throw $exception
            }

            # Validate mandatory properties
            if (-not ($projectObj.Key))
            {
                $message = "The Project provided does not contain all necessary information. Mandatory properties: 'Key'"
                $exception = New-Object -TypeName System.ArgumentException -ArgumentList $message
                Throw $exception
            }
            # These fields are ignored due to the limitations of the rest API
            $ignoredFields = @(
                "Lead"
                "ID"
                "Description"
                "Roles"
                "Key"
                "IssueTypes"
                "Name"
                "RestURL"
                "Components"
            )
            Foreach($key in ($projectObj | Get-Member -MemberType NoteProperty))
            {
                $k = $key.name
                If($ignoredFields -contains $k)
                {
                    Continue
                }
                ElseIf($projectObj.$k)
                {
                    $props["$K"] = $projectObj.$k
                }
            }

            # Validate Project parameter
            if (-not(($Project.PSObject.TypeNames[0] -ne "JiraPS.Project") -or ($Project -isnot [String])))
            {
                $message = "The Project provided is invalid."
                $exception = New-Object -TypeName System.ArgumentException -ArgumentList $message
                Throw $exception
            }
            if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey("projectTypeKey"))
            {
                $props["projectTypeKey"] = $ProjectTypeKey
            }
            if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey("projectTemplateKey"))
            {
                $props["projectTemplateKey"] = $ProjectTemplateKey
            }
            if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey("description"))
            {
                $props["description"] = $Description
            }
            if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey("Lead"))
            {
                $props["lead"] = $Lead
            }
            if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey("AssigneeType"))
            {
                $props["assigneeType"] = $AssigneeType
            }
            if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey("AvatarId"))
            {
                $props["avatarId"] = $AvatarId
            }
            if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey("IssueSecurityScheme"))
            {
                $props["issueSecurityScheme"] = $IssueSecurityScheme
            }
            if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey("PermissionScheme"))
            {
                $props["permissionScheme"] = $PermissionScheme
            }
            if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey("NotificationScheme"))
            {
                $props["notificationScheme"] = $NotificationScheme
            }
            if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey("categoryId"))
            {
                $props["categoryId"] = $CategoryId
            }
            $json = ConvertTo-Json -InputObject $props

            if ($PSCmdlet.ShouldProcess($Name, "Updating Project on JIRA"))
            {
                $results = Invoke-JiraMethod -Method Put -URI $projectUrl -Body $json -Credential $Credential
                If ($results.errormessages)
                {
                    Write-Error $results.errormessages -ErrorAction Stop
                }
                elseif($results)
                {
                    ConvertTo-JiraProject -InputObject $results
                }
                else
                {
                    Write-Verbose "JIRA returned no results."
                }
            }
        }
    }
    end
    {
    }
}
