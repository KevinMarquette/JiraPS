
    #Requires -Version 3

$Script:PSModuleRoot = $PSScriptRoot
# Importing from [C:\git\JiraPS\JiraPS\Private]
# .\JiraPS\Private\ConvertFrom-Json2.ps1
function ConvertFrom-Json2 {
    <#
    .SYNOPSIS
        Function to overwrite or be used instead of the native `ConvertFrom-Json` of PowerShell
    .DESCRIPTION
        ConvertFrom-Json implementation does not allow for overriding JSON maxlength.
        The default limit is easy to exceed with large issue lists.
    #>
    [CmdletBinding()]
    param(
        [Parameter( Mandatory, ValueFromPipeline )]
        [Object[]]
        $InputObject,

        [Int]
        $MaxJsonLength = [Int]::MaxValue
    )

    begin {
        function ConvertFrom-Dictionary {
            param(
                [System.Collections.Generic.IDictionary`2[String, Object]]$InputObject
            )

            process {
                $returnObject = New-Object PSObject

                foreach ($key in $InputObject.Keys) {
                    $pairObjectValue = $InputObject[$key]

                    if ($pairObjectValue -is [System.Collections.Generic.IDictionary`2].MakeGenericType([String], [Object])) {
                        $pairObjectValue = ConvertFrom-Dictionary $pairObjectValue
                    }
                    elseif ($pairObjectValue -is [System.Collections.Generic.ICollection`1].MakeGenericType([Object])) {
                        $pairObjectValue = ConvertFrom-Collection $pairObjectValue
                    }

                    $returnObject | Add-Member Noteproperty $key $pairObjectValue
                }

                return $returnObject
            }
        }

        function ConvertFrom-Collection {
            param(
                [System.Collections.Generic.ICollection`1[Object]]$InputObject
            )

            process {
                $returnList = New-Object ([System.Collections.Generic.List`1].MakeGenericType([Object]))
                foreach ($jsonObject in $InputObject) {
                    $jsonObjectValue = $jsonObject

                    if ($jsonObjectValue -is [System.Collections.Generic.IDictionary`2].MakeGenericType([String], [Object])) {
                        $jsonObjectValue = ConvertFrom-Dictionary $jsonObjectValue
                    }
                    elseif ($jsonObjectValue -is [System.Collections.Generic.ICollection`1].MakeGenericType([Object])) {
                        $jsonObjectValue = ConvertFrom-Collection $jsonObjectValue
                    }

                    $returnList.Add($jsonObjectValue) | Out-Null
                }

                return $returnList.ToArray()
            }
        }

        $scriptAssembly = [System.Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions")

        $typeResolver = @"
public class JsonObjectTypeResolver : System.Web.Script.Serialization.JavaScriptTypeResolver
{
	public override System.Type ResolveType(string id)
	{
		return typeof (System.Collections.Generic.Dictionary<string, object>);
	}

	public override string ResolveTypeId(System.Type type)
	{
		return string.Empty;
	}
}
"@

        try {
            Add-Type -TypeDefinition $typeResolver -ReferencedAssemblies $scriptAssembly.FullName
        }
        catch {
            # This is a relatively common error that's harmless unless changing the actual C#
            # code, so it can be ignored. Unfortunately, it's just a plain old System.Exception,
            # so we can't try to catch a specific error type.
            if (-not $_.ToString() -like "*The type name 'JsonObjectTypeResolver' already exists*") {
                throw $_
            }
        }

        $jsonserial = New-Object System.Web.Script.Serialization.JavaScriptSerializer(New-Object JsonObjectTypeResolver)
        $jsonserial.MaxJsonLength = $MaxJsonLength
    }

    process {
        foreach ($i in $InputObject) {
            $s = $i.ToString()
            if ($s) {
                $jsonTree = $jsonserial.DeserializeObject($s)

                if ($jsonTree -is [System.Collections.Generic.IDictionary`2].MakeGenericType([String], [Object])) {
                    $jsonTree = ConvertFrom-Dictionary $jsonTree
                }
                elseif ($jsonTree -is [System.Collections.Generic.ICollection`1].MakeGenericType([Object])) {
                    $jsonTree = ConvertFrom-Collection $jsonTree
                }

                Write-Output $jsonTree
            }
        }
    }
}

# .\JiraPS\Private\ConvertFrom-URLEncoded.ps1
function ConvertFrom-URLEncoded {
    <#
    .SYNOPSIS
        Decode a URL encoded string
    #>
    [CmdletBinding()]
    [OutputType([String])]
    param (
        # String to decode
        [Parameter( Mandatory, ValueFromPipeline )]
        [String[]]
        $InputString
    )

    process {
        foreach ($input in $InputString) {
            Write-Verbose "[$($MyInvocation.MyCommand.Name)] Decoding string from URL"
            [System.Web.HttpUtility]::UrlDecode($input)
        }
    }
}

# .\JiraPS\Private\ConvertTo-JiraAttachment.ps1
function ConvertTo-JiraAttachment {
    [CmdletBinding()]
    param(
        [Parameter( ValueFromPipeline )]
        [PSObject[]]
        $InputObject
    )

    process {
        foreach ($i in $InputObject) {
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Converting `$InputObject to custom object"

            $props = @{
                'ID'        = $i.id
                'Self'      = $i.self
                'FileName'  = $i.FileName
                'Author'    = ConvertTo-JiraUser -InputObject $i.Author
                'Created'   = Get-Date -Date ($i.created)
                'Size'      = ([Int]$i.size)
                'MimeType'  = $i.mimeType
                'Content'   = $i.content
                'Thumbnail' = $i.thumbnail
            }

            $result = New-Object -TypeName PSObject -Property $props
            $result.PSObject.TypeNames.Insert(0, 'JiraPS.Attachment')
            $result | Add-Member -MemberType ScriptMethod -Name "ToString" -Force -Value {
                Write-Output "$($this.FileName)"
            }

            Write-Output $result
        }
    }
}



# .\JiraPS\Private\ConvertTo-JiraComment.ps1
function ConvertTo-JiraComment {
    [CmdletBinding()]
    param(
        [Parameter( ValueFromPipeline )]
        [PSObject[]]
        $InputObject
    )

    process {
        foreach ($i in $InputObject) {
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Converting `$InputObject to custom object"

            $props = @{
                'ID'         = $i.id
                'Body'       = $i.body
                'Visibility' = $i.visibility
                'RestUrl'    = $i.self
            }

            if ($i.author) {
                $props.Author = ConvertTo-JiraUser -InputObject $i.author
            }

            if ($i.updateAuthor) {
                $props.UpdateAuthor = ConvertTo-JiraUser -InputObject $i.updateAuthor
            }

            if ($i.created) {
                $props.Created = (Get-Date ($i.created))
            }

            if ($i.updated) {
                $props.Updated = (Get-Date ($i.updated))
            }

            $result = New-Object -TypeName PSObject -Property $props
            $result.PSObject.TypeNames.Insert(0, 'JiraPS.Comment')
            $result | Add-Member -MemberType ScriptMethod -Name "ToString" -Force -Value {
                Write-Output "$($this.Body)"
            }

            Write-Output $result
        }
    }
}

# .\JiraPS\Private\ConvertTo-JiraComponent.ps1
function ConvertTo-JiraComponent {
    [CmdletBinding()]
    param(
        [Parameter( ValueFromPipeline )]
        [PSObject[]]
        $InputObject
    )

    process {
        foreach ($i in $InputObject) {
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Converting `$InputObject to custom object"

            $props = @{
                'ID'          = $i.id
                'Name'        = $i.name
                'RestUrl'     = $i.self
                'Lead'        = $i.lead
                'ProjectName' = $i.project
                'ProjectId'   = $i.projectId
            }

            if ($i.lead) {
                $props.Lead = $i.lead
                $props.LeadDisplayName = $i.lead.displayName
            }
            else {
                $props.Lead = $null
                $props.LeadDisplayName = $null
            }

            $result = New-Object -TypeName PSObject -Property $props
            $result.PSObject.TypeNames.Insert(0, 'JiraPS.Component')
            $result | Add-Member -MemberType ScriptMethod -Name "ToString" -Force -Value {
                Write-Output "$($this.Name)"
            }

            Write-Output $result
        }
    }
}

# .\JiraPS\Private\ConvertTo-JiraCreateMetaField.ps1
function ConvertTo-JiraCreateMetaField {
    [CmdletBinding()]
    param(
        [Parameter( ValueFromPipeline )]
        [PSObject[]]
        $InputObject
    )

    process {
        foreach ($i in $InputObject) {
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Converting `$InputObject to custom object"

            $fields = $i.projects.issuetypes.fields
            $fieldNames = (Get-Member -InputObject $fields -MemberType '*Property').Name
            foreach ($f in $fieldNames) {
                $item = $fields.$f

                $props = @{
                    'Id'              = $f
                    'Name'            = $item.name
                    'HasDefaultValue' = [System.Convert]::ToBoolean($item.hasDefaultValue)
                    'Required'        = [System.Convert]::ToBoolean($item.required)
                    'Schema'          = $item.schema
                    'Operations'      = $item.operations
                }

                if ($item.allowedValues) {
                    $props.AllowedValues = $item.allowedValues
                }

                if ($item.autoCompleteUrl) {
                    $props.AutoCompleteUrl = $item.autoCompleteUrl
                }

                foreach ($extraProperty in (Get-Member -InputObject $item -MemberType NoteProperty).Name) {
                    if ($null -eq $props.$extraProperty) {
                        $props.$extraProperty = $item.$extraProperty
                    }
                }

                $result = New-Object -TypeName PSObject -Property $props
                $result.PSObject.TypeNames.Insert(0, 'JiraPS.CreateMetaField')
                $result | Add-Member -MemberType ScriptMethod -Name "ToString" -Force -Value {
                    Write-Output "$($this.Name)"
                }

                Write-Output $result
            }
        }
    }
}

# .\JiraPS\Private\ConvertTo-JiraEditMetaField.ps1
function ConvertTo-JiraEditMetaField {
    [CmdletBinding()]
    param(
        [Parameter( ValueFromPipeline )]
        [PSObject[]]
        $InputObject
    )

    process {
        foreach ($i in $InputObject) {
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Converting `$InputObject to custom object"

            $fields = $i.fields
            $fieldNames = (Get-Member -InputObject $fields -MemberType '*Property').Name
            foreach ($f in $fieldNames) {
                $item = $fields.$f

                $props = @{
                    'Id'              = $f
                    'Name'            = $item.name
                    'HasDefaultValue' = [System.Convert]::ToBoolean($item.hasDefaultValue)
                    'Required'        = [System.Convert]::ToBoolean($item.required)
                    'Schema'          = $item.schema
                    'Operations'      = $item.operations
                }

                if ($item.allowedValues) {
                    $props.AllowedValues = $item.allowedValues
                }

                if ($item.autoCompleteUrl) {
                    $props.AutoCompleteUrl = $item.autoCompleteUrl
                }

                foreach ($extraProperty in (Get-Member -InputObject $item -MemberType NoteProperty).Name) {
                    if ($null -eq $props.$extraProperty) {
                        $props.$extraProperty = $item.$extraProperty
                    }
                }

                $result = New-Object -TypeName PSObject -Property $props
                $result.PSObject.TypeNames.Insert(0, 'JiraPS.EditMetaField')
                $result | Add-Member -MemberType ScriptMethod -Name "ToString" -Force -Value {
                    Write-Output "$($this.Name)"
                }

                Write-Output $result
            }
        }
    }
}

# .\JiraPS\Private\ConvertTo-JiraField.ps1
function ConvertTo-JiraField {
    [CmdletBinding()]
    param(
        [Parameter( ValueFromPipeline )]
        [PSObject[]]
        $InputObject
    )

    process {
        foreach ($i in $InputObject) {
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Converting `$InputObject to custom object"

            $props = @{
                'ID'          = $i.id
                'Name'        = $i.name
                'Custom'      = [System.Convert]::ToBoolean($i.custom)
                'Orderable'   = [System.Convert]::ToBoolean($i.orderable)
                'Navigable'   = [System.Convert]::ToBoolean($i.navigable)
                'Searchable'  = [System.Convert]::ToBoolean($i.searchable)
                'ClauseNames' = $i.clauseNames
                'Schema'      = $i.schema
            }

            $result = New-Object -TypeName PSObject -Property $props
            $result.PSObject.TypeNames.Insert(0, 'JiraPS.Field')
            $result | Add-Member -MemberType ScriptMethod -Name "ToString" -Force -Value {
                Write-Output "$($this.Name)"
            }

            Write-Output $result
        }
    }
}

# .\JiraPS\Private\ConvertTo-JiraFilter.ps1
function ConvertTo-JiraFilter {
    [CmdletBinding()]
    param(
        [Parameter( ValueFromPipeline )]
        [PSObject[]]
        $InputObject
    )

    process {
        foreach ($i in $InputObject) {
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Converting `$InputObject to custom object"

            $props = @{
                'ID'              = $i.id
                'Name'            = $i.name
                'JQL'             = $i.jql
                'RestUrl'         = $i.self
                'ViewUrl'         = $i.viewUrl
                'SearchUrl'       = $i.searchUrl
                'Favourite'       = $i.favourite

                'SharePermission' = $i.sharePermissions
                'SharedUser'      = $i.sharedUsers
                'Subscription'    = $i.subscriptions
            }

            if ($i.description) {
                $props.Description = $i.description
            }

            if ($i.owner) {
                $props.Owner = ConvertTo-JiraUser -InputObject $i.owner
            }

            $result = New-Object -TypeName PSObject -Property $props
            $result.PSObject.TypeNames.Insert(0, 'JiraPS.Filter')
            $result | Add-Member -MemberType ScriptMethod -Name 'ToString' -Force -Value {
                Write-Output "$($this.Name)"
            }
            $result | Add-Member -MemberType AliasProperty -Name 'Favorite' -Value 'Favourite'

            Write-Output $result
        }
    }
}

# .\JiraPS\Private\ConvertTo-JiraGroup.ps1
function ConvertTo-JiraGroup {
    [CmdletBinding()]
    param(
        [Parameter( ValueFromPipeline )]
        [PSObject[]]
        $InputObject
    )

    process {
        foreach ($i in $InputObject) {
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Converting `$InputObject to custom object"

            $props = @{
                'Name'    = $i.name
                'RestUrl' = $i.self
            }

            if ($i.users) {
                $props.Size = $i.users.size

                if ($i.users.items) {
                    $allUsers = New-Object -TypeName System.Collections.ArrayList
                    foreach ($user in $i.users.items) {
                        [void] $allUsers.Add( (ConvertTo-JiraUser -InputObject $user) )
                    }

                    $props.Member = ($allUsers.ToArray())
                }
            }

            $result = New-Object -TypeName PSObject -Property $props
            $result.PSObject.TypeNames.Insert(0, 'JiraPS.Group')
            $result | Add-Member -MemberType ScriptMethod -Name "ToString" -Force -Value {
                Write-Output "$($this.Name)"
            }

            Write-Output $result
        }
    }
}

# .\JiraPS\Private\ConvertTo-JiraIssue.ps1
function ConvertTo-JiraIssue {
    [CmdletBinding()]
    param(
        [Parameter( ValueFromPipeline )]
        [PSObject[]]
        $InputObject,

        [Switch]
        $IncludeDebug
    )

    begin {
        $userFields = @('Assignee', 'Creator', 'Reporter')
        $dateFields = @('Created', 'LastViewed', 'Updated')

        $transitions = New-Object -TypeName System.Collections.ArrayList
        $comments = New-Object -TypeName System.Collections.ArrayList
    }

    process {
        foreach ($i in $InputObject) {
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Converting `$InputObject to custom object"

            [void] $transitions.Clear()
            [void] $comments.Clear()

            $http = "{0}browse/$($i.key)" -f ($InputObject.self -split 'rest')[0]

            $props = @{
                'ID'          = $i.id
                'Key'         = $i.key
                'HttpUrl'     = $http
                'RestUrl'     = $i.self
                'Summary'     = $i.fields.summary
                'Description' = $i.fields.description
                'Status'      = $i.fields.status.name
            }

            if ($i.fields.issuelinks) {
                $props['IssueLinks'] = ConvertTo-JiraIssueLink -InputObject $i.fields.issuelinks
            }

            if ($i.fields.attachment) {
                $props["Attachment"] = ConvertTo-JiraAttachment $i.fields.attachment
            }

            if ($i.fields.project) {
                $props.Project = ConvertTo-JiraProject -InputObject $i.fields.project
            }

            foreach ($field in $userFields) {
                if ($i.fields.$field) {
                    $props.$field = ConvertTo-JiraUser -InputObject $i.fields.$field
                }
                elseif ($field -eq 'Assignee') {
                    $props.Assignee = 'Unassigned'
                }
                else {
                }
            }

            foreach ($field in $dateFields) {
                if ($i.fields.$field) {
                    $props.$field = Get-Date -Date ($i.fields.$field)
                }
            }

            if ($IncludeDebug) {
                $props.Fields = $i.fields
                $props.Expand = $i.expand
            }

            [void] $transitions.Clear()
            foreach ($t in $i.transitions) {
                [void] $transitions.Add( (ConvertTo-JiraTransition -InputObject $t) )
            }
            $props.Transition = $transitions.ToArray()

            [void] $comments.Clear()
            if ($i.fields.comment) {
                if ($i.fields.comment.comments) {
                    foreach ($c in $i.fields.comment.comments) {
                        [void] $comments.Add( (ConvertTo-JiraComment -InputObject $c) )
                    }
                    $props.Comment = $comments.ToArray()
                }
            }

            $extraFields = $i.fields.PSObject.Properties | Where-Object -FilterScript { $_.Name -notin $props.Keys }
            foreach ($f in $extraFields) {
                $name = $f.Name
                $props[$name] = $f.Value
            }

            $result = New-Object -TypeName PSObject -Property $props
            $result.PSObject.TypeNames.Insert(0, 'JiraPS.Issue')
            $result | Add-Member -MemberType ScriptMethod -Name "ToString" -Force -Value {
                Write-Output "[$($this.Key)] $($this.Summary)"
            }

            Write-Output $result
        }
    }
}

# .\JiraPS\Private\ConvertTo-JiraIssueLink.ps1
function ConvertTo-JiraIssueLink {
    [CmdletBinding()]
    param(
        [Parameter( ValueFromPipeline )]
        [PSObject[]]
        $InputObject
    )

    process {
        foreach ($i in $InputObject) {
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Converting `$InputObject to custom object"

            $props = @{
                'ID'   = $i.id
                'Type' = ConvertTo-JiraIssueLinkType $i.type
            }

            if ($i.inwardIssue) {
                $props['InwardIssue'] = ConvertTo-JiraIssue $i.inwardIssue
            }

            if ($i.outwardIssue) {
                $props['OutwardIssue'] = ConvertTo-JiraIssue $i.outwardIssue
            }

            $result = New-Object -TypeName PSObject -Property $props
            $result.PSObject.TypeNames.Insert(0, 'JiraPS.IssueLink')
            $result | Add-Member -MemberType ScriptMethod -Name "ToString" -Force -Value {
                Write-Output "$($this.ID)"
            }

            Write-Output $result
        }
    }
}

# .\JiraPS\Private\ConvertTo-JiraIssueLinkType.ps1
function ConvertTo-JiraIssueLinkType {
    [CmdletBinding()]
    param(
        [Parameter( ValueFromPipeline )]
        [PSObject[]]
        $InputObject
    )

    process {
        foreach ($i in $InputObject) {
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Converting `$InputObject to custom object"

            $props = @{
                'ID'          = $i.id
                'Name'        = $i.name
                'InwardText'  = $i.inward
                'OutwardText' = $i.outward
                'RestUrl'     = $i.self
            }

            $result = New-Object -TypeName PSObject -Property $props
            $result.PSObject.TypeNames.Insert(0, 'JiraPS.IssueLinkType')
            $result | Add-Member -MemberType ScriptMethod -Name "ToString" -Force -Value {
                Write-Output "$($this.Name)"
            }

            Write-Output $result
        }
    }
}

# .\JiraPS\Private\ConvertTo-JiraIssueType.ps1
function ConvertTo-JiraIssueType {
    [CmdletBinding()]
    param(
        [Parameter( ValueFromPipeline )]
        [PSObject[]]
        $InputObject
    )

    process {
        foreach ($i in $InputObject) {
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Converting `$InputObject to custom object"

            $props = @{
                'ID'          = $i.id
                'Name'        = $i.name
                'Description' = $i.description
                'IconUrl'     = $i.iconUrl
                'RestUrl'     = $i.self
                'Subtask'     = [System.Convert]::ToBoolean($i.subtask)
            }

            $result = New-Object -TypeName PSObject -Property $props
            $result.PSObject.TypeNames.Insert(0, 'JiraPS.IssueType')
            $result | Add-Member -MemberType ScriptMethod -Name "ToString" -Force -Value {
                Write-Output "$($this.Name)"
            }

            Write-Output $result
        }
    }
}

# .\JiraPS\Private\ConvertTo-JiraLink.ps1
function ConvertTo-JiraLink {
    [CmdletBinding()]
    param(
        [Parameter( ValueFromPipeline )]
        [PSObject[]]
        $InputObject
    )

    process {
        foreach ($i in $InputObject) {
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Converting `$InputObject to custom object"

            $props = @{
                'Id'      = $i.id
                'RestUrl' = $i.self
            }

            if ($i.globalId) {
                $props.globalId = $i.globalId
            }

            if ($i.application) {
                $props.application = New-Object PSObject -Prop @{
                    type = $i.application.type
                    name = $i.application.name
                }
            }

            if ($i.relationship) {
                $props.relationship = $i.relationship
            }

            if ($i.object) {
                if ($i.object.icon) {
                    $icon = New-Object PSObject -Prop @{
                        title    = $i.object.icon.title
                        url16x16 = $i.object.icon.url16x16
                    }
                }
                else { $icon = $null }

                if ($i.object.status.icon) {
                    $statusIcon = New-Object PSObject -Prop @{
                        link     = $i.object.status.icon.link
                        title    = $i.object.status.icon.title
                        url16x16 = $i.object.status.icon.url16x16
                    }
                }
                else { $statusIcon = $null }

                if ($i.object.status) {
                    $status = New-Object PSObject -Prop @{
                        resolved = $i.object.status.resolved
                        icon     = $statusIcon
                    }
                }
                else { $status = $null }

                $props.object = New-Object PSObject -Prop @{
                    url     = $i.object.url
                    title   = $i.object.title
                    summary = $i.object.summary
                    icon    = $icon
                    status  = $status
                }
            }

            $result = New-Object -TypeName PSObject -Property $props
            $result.PSObject.TypeNames.Insert(0, 'JiraPS.Link')
            $result | Add-Member -MemberType ScriptMethod -Name "ToString" -Force -Value {
                Write-Output "$($this.Id)"
            }

            Write-Output $result
        }
    }
}

# .\JiraPS\Private\ConvertTo-JiraPriority.ps1
function ConvertTo-JiraPriority {
    [CmdletBinding()]
    param(
        [Parameter( ValueFromPipeline )]
        [PSObject[]]
        $InputObject
    )

    process {
        foreach ($i in $InputObject) {
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Converting `$InputObject to custom object"

            $props = @{
                'ID'          = $i.id
                'Name'        = $i.name
                'Description' = $i.description
                'StatusColor' = $i.statusColor
                'IconUrl'     = $i.iconUrl
                'RestUrl'     = $i.self
            }

            $result = New-Object -TypeName PSObject -Property $props
            $result.PSObject.TypeNames.Insert(0, 'JiraPS.Priority')
            $result | Add-Member -MemberType ScriptMethod -Name "ToString" -Force -Value {
                Write-Output "$($this.Name)"
            }

            Write-Output $result
        }
    }
}

# .\JiraPS\Private\ConvertTo-JiraProject.ps1
function ConvertTo-JiraProject {
    [CmdletBinding()]
    param(
        [Parameter( ValueFromPipeline )]
        [PSObject[]]
        $InputObject
    )

    process {
        foreach ($i in $InputObject) {
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Converting `$InputObject to custom object"

            $props = @{
                'ID'          = $i.id
                'Key'         = $i.key
                'Name'        = $i.name
                'Description' = $i.description
                'Lead'        = ConvertTo-JiraUser $i.lead
                'IssueTypes'  = ConvertTo-JiraIssueType $i.issueTypes
                'Roles'       = $i.roles
                'RestUrl'     = $i.self
                'Components'  = $i.components
            }

            if ($i.projectCategory) {
                $props.Category = $i.projectCategory
            }
            elseif ($i.Category) {
                $props.Category = $i.Category
            }
            else {
                $props.Category = $null
            }

            $result = New-Object -TypeName PSObject -Property $props
            $result.PSObject.TypeNames.Insert(0, 'JiraPS.Project')
            $result | Add-Member -MemberType ScriptMethod -Name "ToString" -Force -Value {
                Write-Output "$($this.Name)"
            }

            Write-Output $result
        }
    }
}

# .\JiraPS\Private\ConvertTo-JiraServerInfo.ps1
function ConvertTo-JiraServerInfo {
    [CmdletBinding()]
    param(
        [Parameter( ValueFromPipeline )]
        [PSObject[]]
        $InputObject
    )

    process {
        foreach ($i in $InputObject) {
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Converting `$InputObject to custom object"

            $props = @{
                'BaseURL'        = $i.baseUrl
                # With PoSh v6, the version shall be casted to [SemanticVersion]
                'Version'        = $i.version
                'DeploymentType' = $i.deploymentType
                'BuildNumber'    = $i.buildNumber
                'BuildDate'      = Get-Date $i.buildDate
                'ServerTime'     = Get-Date $i.serverTime
                'ScmInfo'        = $i.scmInfo
                'ServerTitle'    = $i.serverTitle
            }

            $result = New-Object -TypeName PSObject -Property $props
            $result.PSObject.TypeNames.Insert(0, 'JiraPS.ServerInfo')
            $result | Add-Member -MemberType ScriptMethod -Name "ToString" -Force -Value {
                Write-Output "[$($this.DeploymentType)] $($this.Version)"
            }

            Write-Output $result
        }
    }
}

# .\JiraPS\Private\ConvertTo-JiraSession.ps1
function ConvertTo-JiraSession {
    [CmdletBinding()]
    param(
        [Parameter( Mandatory )]
        [Microsoft.PowerShell.Commands.WebRequestSession]
        $Session,

        [String]
        $Username
    )

    process {
        Write-Debug "[$($MyInvocation.MyCommand.Name)] Converting `$InputObject to custom object"

        $props = @{
            'WebSession' = $Session
        }

        if ($Username) {
            $props.Username = $Username
        }

        $result = New-Object -TypeName PSObject -Property $props
        $result.PSObject.TypeNames.Insert(0, 'JiraPS.Session')
        $result | Add-Member -MemberType ScriptMethod -Name "ToString" -Force -Value {
            Write-Output "JiraSession[JSessionID=$($this.JSessionID)]"
        }

        Write-Output $result
    }
}

# .\JiraPS\Private\ConvertTo-JiraStatus.ps1
function ConvertTo-JiraStatus {
    [CmdletBinding()]
    param(
        [Parameter( ValueFromPipeline )]
        [PSObject[]]
        $InputObject
    )

    process {
        foreach ($i in $InputObject) {
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Converting `$InputObject to custom object"

            $props = @{
                'ID'          = $i.id
                'Name'        = $i.name
                'Description' = $i.description
                'IconUrl'     = $i.iconUrl
                'RestUrl'     = $i.self
            }

            $result = New-Object -TypeName PSObject -Property $props
            $result.PSObject.TypeNames.Insert(0, 'JiraPS.Status')
            $result | Add-Member -MemberType ScriptMethod -Name "ToString" -Force -Value {
                Write-Output "$($this.Name)"
            }

            Write-Output $result
        }
    }
}

# .\JiraPS\Private\ConvertTo-JiraTransition.ps1
function ConvertTo-JiraTransition {
    [CmdletBinding()]
    param(
        [Parameter( ValueFromPipeline )]
        [PSObject[]]
        $InputObject
    )

    process {
        foreach ($i in $InputObject) {
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Converting `$InputObject to custom object"

            $props = @{
                'ID'           = $i.id
                'Name'         = $i.name
                'ResultStatus' = ConvertTo-JiraStatus -InputObject $i.to
            }

            $result = New-Object -TypeName PSObject -Property $props
            $result.PSObject.TypeNames.Insert(0, 'JiraPS.Transition')
            $result | Add-Member -MemberType ScriptMethod -Name "ToString" -Force -Value {
                Write-Output "$($this.Name)"
            }

            Write-Output $result
        }
    }
}

# .\JiraPS\Private\ConvertTo-JiraUser.ps1
function ConvertTo-JiraUser {
    [CmdletBinding()]
    param(
        [Parameter( ValueFromPipeline )]
        [PSObject[]]
        $InputObject
    )

    process {
        foreach ($i in $InputObject) {
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Converting `$InputObject to custom object"

            $props = @{
                'Key'          = $i.key
                'AccountId'    = $i.accountId
                'Name'         = $i.name
                'DisplayName'  = $i.displayName
                'EmailAddress' = $i.emailAddress
                'Active'       = [System.Convert]::ToBoolean($i.active)
                'AvatarUrl'    = $i.avatarUrls
                'TimeZone'     = $i.timeZone
                'Locale'       = $i.locale
                'Groups'       = $i.groups.items
                'RestUrl'      = $i.self
            }

            if ($i.groups) {
                $props.Groups = $i.groups.items.name
            }

            $result = New-Object -TypeName PSObject -Property $props
            $result.PSObject.TypeNames.Insert(0, 'JiraPS.User')
            $result | Add-Member -MemberType ScriptMethod -Name "ToString" -Force -Value {
                Write-Output "$($this.Name)"
            }

            Write-Output $result
        }
    }
}

# .\JiraPS\Private\ConvertTo-JiraVersion.ps1
function ConvertTo-JiraVersion {
    [CmdletBinding()]
    param(
        [Parameter( ValueFromPipeline )]
        [PSObject[]]
        $InputObject
    )

    process {
        foreach ($i in $InputObject) {
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Converting `$InputObject to custom object"

            $props = @{
                'ID'          = $i.id
                'Project'     = $i.projectId
                'Name'        = $i.name
                'Description' = $i.description
                'Archived'    = $i.archived
                'Released'    = $i.released
                'Overdue'     = $i.overdue
                'RestUrl'     = $i.self
            }

            if ($i.startDate) {
                $props["StartDate"] = Get-Date $i.startDate
            }
            else {
                $props["StartDate"] = ""
            }

            if ($i.releaseDate) {
                $props["ReleaseDate"] = Get-Date $i.releaseDate
            }
            else {
                $props["ReleaseDate"] = ""
            }

            $result = New-Object -TypeName PSObject -Property $props
            $result.PSObject.TypeNames.Insert(0, 'JiraPS.Version')
            $result | Add-Member -MemberType ScriptMethod -Name "ToString" -Force -Value {
                Write-Output "$($this.Name)"
            }

            Write-Output $result
        }
    }
}

# .\JiraPS\Private\ConvertTo-JiraWorklogitem.ps1
function ConvertTo-JiraWorklogItem {
    [CmdletBinding()]
    param(
        [Parameter( ValueFromPipeline )]
        [PSObject[]]
        $InputObject
    )

    process {
        foreach ($i in $InputObject) {
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Converting `$InputObject to custom object"

            $props = @{
                'ID'         = $i.id
                'Visibility' = $i.visibility
                'Comment'    = $i.comment
                'RestUrl'    = $i.self
            }

            if ($i.author) {
                $props.Author = ConvertTo-JiraUser -InputObject $i.author
            }

            if ($i.updateAuthor) {
                $props.UpdateAuthor = ConvertTo-JiraUser -InputObject $i.updateAuthor
            }

            if ($i.created) {
                $props.Created = Get-Date ($i.created)
            }

            if ($i.updated) {
                $props.Updated = Get-Date ($i.updated)
            }

            if ($i.started) {
                $props.Started = Get-Date ($i.started)
            }

            if ($i.timeSpent) {
                $props.TimeSpent = $i.timeSpent
            }

            if ($i.timeSpentSeconds) {
                $props.TimeSpentSeconds = $i.timeSpentSeconds
            }

            $result = New-Object -TypeName PSObject -Property $props
            $result.PSObject.TypeNames.Insert(0, 'JiraPS.Worklogitem')
            $result | Add-Member -MemberType ScriptMethod -Name "ToString" -Force -Value {
                Write-Output "$($this.Id)"
            }

            Write-Output $result
        }
    }
}

# .\JiraPS\Private\ConvertTo-URLEncoded.ps1
function ConvertTo-URLEncoded {
    <#
    .SYNOPSIS
        Encode a string into URL (eg: %20 instead of " ")
    #>
    [CmdletBinding()]
    [OutputType([String])]
    param (
        # String to encode
        [Parameter( Mandatory, ValueFromPipeline )]
        [String[]]
        $InputString
    )

    process {
        foreach ($input in $InputString) {
            Write-Verbose "[$($MyInvocation.MyCommand.Name)] Encoding string to URL"
            [System.Web.HttpUtility]::UrlEncode($input)
        }
    }
}

# .\JiraPS\Private\Invoke-JiraMethod.ps1
function Invoke-JiraMethod {
    [CmdletBinding()]
    param
    (
        # REST API to invoke
        [Parameter( Mandatory )]
        [Uri]
        $URI,

        # Method of the invokation
        [ValidateSet('GET', 'POST', 'PUT', 'DELETE')]
        [String]
        $Method = "GET",

        # Body of the request
        [String]
        $Body,

        # Body of the request should not be encoded
        [Switch]
        $RawBody,

        # Custom headers for the HTTP request
        [Hashtable]
        $Headers = @{},

        # Authentication credentials
        [PSCredential]
        $Credential
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"

        # Validation of parameters
        if (
            ($Method -in ("POST", "PUT")) -and
            (-not ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey("Body")))
        ) {
            $message = "The following parameters are required when using the $Method parameter: Body."
            $exception = New-Object -TypeName System.ArgumentException -ArgumentList $message
            Throw $exception
        }

        # load DefaultParameters for Invoke-WebRequest
        # as the global PSDefaultParameterValues is not used
        $PSDefaultParameterValues = $global:PSDefaultParameterValues

        # pass input to local variable
        # this allows to use the PSBoundParameters for recursion
        $_headers = $Headers

        # Check if a Session is available
        $session = Get-JiraSession -ErrorAction SilentlyContinue

        if ($Credential) {
            $SecureCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(
                    $('{0}:{1}' -f $Credential.UserName, $Credential.GetNetworkCredential().Password)
                ))
            $_headers.Add('Authorization', "Basic $SecureCreds")
            Write-Verbose "[$($MyInvocation.MyCommand.Name)] Using HTTP Basic authentication with username $($Credential.UserName)"
        }
        elseif ($session) {
            Write-Verbose "[$($MyInvocation.MyCommand.Name)] Using WebSession (Username=[$($session.Username)])"
        }
        else {
            $session = $null
            Write-Verbose "[$($MyInvocation.MyCommand.Name)] No Credentials or WebSession provided; using anonymous access"
        }
    }

    process {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] ParameterSetName: $($PsCmdlet.ParameterSetName)"
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] PSBoundParameters: $($PSBoundParameters | Out-String)"

        $iwrSplat = @{
            Uri             = $Uri
            Headers         = $_headers
            Method          = $Method
            ContentType     = 'application/json; charset=utf-8'
            UseBasicParsing = $true
            ErrorAction     = 'SilentlyContinue'
            Verbose = $false
        }

        if ($_headers.ContainsKey("Content-Type")) {
            $iwrSplat["ContentType"] = $_headers["Content-Type"]
            $_headers.Remove("Content-Type")
            $iwrSplat["Headers"] = $_headers
        }

        if ($Body) {
            if ($RawBody) {
                $iwrSplat.Add('Body', $Body)
            }
            else {
                # http://stackoverflow.com/questions/15290185/invoke-webrequest-issue-with-special-characters-in-json
                $iwrSplat.Add('Body', [System.Text.Encoding]::UTF8.GetBytes($Body))
            }
        }

        if ($session) {
            $iwrSplat.Add('WebSession', $session.WebSession)
        }

        try {
            Write-Verbose "[$($MyInvocation.MyCommand.Name)] $($iwrSplat.Method) $($iwrSplat.Uri)"
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoke-WebRequest with `$iwrSplat: $($iwrSplat | Out-String)"
            $webResponse = Invoke-WebRequest @iwrSplat
        }
        catch {
            # Invoke-WebRequest is hard-coded to throw an exception if the Web request returns a 4xx or 5xx error.
            # This is the best workaround I can find to retrieve the actual results of the request.
            $webResponse = $_.Exception.Response
        }
    }

    end {
        Write-Debug "[$($MyInvocation.MyCommand.Name)] Status code:  $($webResponse.StatusCode.value__) - $($webResponse.StatusCode) `n`t`t Executed WebRequest. Access `$webResponse to see details"

        if ($webResponse) {
            if ($webResponse.StatusCode.value__ -gt 399) {
                # Retrieve body of HTTP response - this contains more useful information about exactly why the error occurred
                $readStream = New-Object -TypeName System.IO.StreamReader -ArgumentList ($webResponse.GetResponseStream())
                $responseBody = $readStream.ReadToEnd()
                $readStream.Close()
                Write-Debug "[$($MyInvocation.MyCommand.Name)] Retrieved body of HTTP response for more information about the error (`$responseBody)"
                $result = ConvertFrom-Json2 -InputObject $responseBody
            }
            else {
                if ($webResponse.Content) {
                    $result = ConvertFrom-Json2 -InputObject $webResponse.Content
                }
            }

            if ($result) {
                if (Get-Member -Name "Errors" -InputObject $result -ErrorAction SilentlyContinue) {
                    Resolve-JiraError $result -WriteError
                }
                else {
                    Write-Output $result
                }
            }
        }
        else {
            Write-Verbose "[$($MyInvocation.MyCommand.Name)] No Web result object was returned from JIRA. This is unusual!"
        }

        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function ended"
    }
}

# .\JiraPS\Private\Resolve-JiraError.ps1
function Resolve-JiraError {
    [CmdletBinding()]
    param(
        [Parameter( ValueFromPipeline )]
        [Object[]]
        $InputObject,

        # Write error results to the error stream (Write-Error) instead of to the output stream
        [Switch]
        $WriteError
    )

    process {
        foreach ($i in $InputObject) {
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Converting `$InputObject to custom object"

            if ($i.errorMessages) {
                foreach ($e in $i.errorMessages) {
                    if ($WriteError) {
                        Write-Error "JiraPS encountered an error: [$e]"
                    }
                    else {
                        $obj = [PSCustomObject] @{
                            'Message' = $e
                        }

                        $obj.PSObject.TypeNames.Insert(0, 'JiraPS.Error')
                        $obj | Add-Member -MemberType ScriptMethod -Name "ToString" -Force -Value {
                            Write-Output "Jira error [$($this.Message)]"
                        }

                        Write-Output $obj
                    }
                }
            }
            elseif ($i.errors) {
                $keys = (Get-Member -InputObject $i.errors | Where-Object -FilterScript {$_.MemberType -eq 'NoteProperty'}).Name
                foreach ($k in $keys) {
                    if ($WriteError) {
                        Write-Error "Jira encountered an error: [$k] - $($i.errors.$k)"
                    }
                    else {
                        $obj = [PSCustomObject] @{
                            'Key'     = $k
                            'Message' = $i.errors.$k
                        }

                        $obj.PSObject.TypeNames.Insert(0, 'JiraPS.Error')
                        $obj | Add-Member -MemberType ScriptMethod -Name "ToString" -Force -Value {
                            Write-Output "Jira error [$($this.ID)]: $($this.Message)"
                        }

                        Write-Output $obj
                    }
                }
            }
        }
    }
}

# .\JiraPS\Private\Resolve-JiraIssueObject.ps1
function Resolve-JiraIssueObject {
    <#
      #ToDo:CustomClass
      Once we have custom classes, this will no longer be necessary
    #>
    [CmdletBinding()]
    param(
        [Parameter( ValueFromPipeline )]
        [ValidateNotNullOrEmpty()]
        [ValidateScript(
            {
                if (("JiraPS.Issue" -notin $_.PSObject.TypeNames) -and (($_ -isnot [String]))) {
                    $errorItem = [System.Management.Automation.ErrorRecord]::new(
                        ([System.ArgumentException]"Invalid Type for Parameter"),
                        'ParameterType.NotJiraIssue',
                        [System.Management.Automation.ErrorCategory]::InvalidArgument,
                        $_
                    )
                    $errorItem.ErrorDetails = "Wrong object type provided for Issue. Expected [JiraPS.Issue] or [String], but was $($_.GetType().Name)"
                    $PSCmdlet.ThrowTerminatingError($errorItem)
                }
                else {
                    return $true
                }
            }
        )]
        [Object]
        $InputObject,

        # Authentication credentials
        [PSCredential]
        $Credential
    )

    # As we are not able to use proper type casting in the parameters, this is a workaround
    # to extract the data from a JiraPS.Issue object
    # This shall be removed once we have custom classes for the module
    if ("JiraPS.Issue" -in $InputObject.PSObject.TypeNames -and $InputObject.RestURL) {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] Using `$Issue as object"
        return $Issue
    }
    elseif ("JiraPS.Issue" -in $InputObject.PSObject.TypeNames -and $InputObject.Key) {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] Resolve Issue to object"
        return Get-JiraIssue -Key $InputObject.Key -Credential $Credential -ErrorAction Stop
    }
    else {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] Resolve Issue to object"
        return Get-JiraIssue -Key $InputObject.ToString() -Credential $Credential -ErrorAction Stop
    }
}

# .\JiraPS\Private\Set-TlsLevel.ps1
function Set-TlsLevel {
    [CmdletBinding( SupportsShouldProcess = $false )]
    [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseShouldProcessForStateChangingFunctions', '')]
    param (
        [Parameter(Mandatory, ParameterSetName = 'Set')]
        [Switch]$Tls12,

        [Parameter(Mandatory, ParameterSetName = 'Revert')]
        [Switch]$Revert
    )

    begin {
        switch ($PSCmdlet.ParameterSetName) {
            "Set" {
                $Script:OriginalTlsSettings = [Net.ServicePointManager]::SecurityProtocol

                [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.ServicePointManager]::Tls12
            }
            "Revert" {
                [Net.ServicePointManager]::SecurityProtocol = $Script:OriginalTlsSettings
            }
        }
    }
}

# .\JiraPS\Private\Test-Captcha.ps1
function Test-Captcha {
    [CmdletBinding()]
    param(
        # Response of Invoke-WebRequest
        [Parameter( ValueFromPipeline )]
        [Microsoft.PowerShell.Commands.WebResponseObject]
        $InputObject
    )

    begin {
        $tokenRequiresCaptcha = "AUTHENTICATION_DENIED"
        $LoginReason = "X-Seraph-LoginReason"
    }

    process {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Checking response headers for authentication errors"
        Write-Debug "[$($MyInvocation.MyCommand.Name)] Investigating `$InputObject.Headers['$LoginReason']"

        if ($InputObject.Headers -and $InputObject.Headers[$LoginReason]) {
            if ( ($InputObject.Headers[$LoginReason] -split ",") -contains $tokenRequiresCaptcha ) {
                $errorMessage = @{
                    Category         = "AuthenticationError"
                    CategoryActivity = "Authentication"
                    Message          = "JIRA requires you to log on to the website before continuing for security reasons."
                }
                Write-Error @errorMessage
            }
        }
    }

    end {
    }
}

# .\JiraPS\Private\Write-DebugMessage.ps1
function Write-DebugMessage {
    [CmdletBinding()]
    param(
        [Parameter( ValueFromPipeline )]
        [String]
        $Message
    )

    begin {
        $oldDebugPreference = $DebugPreference
        if (-not ($DebugPreference -eq "SilentlyContinue")) {
            $DebugPreference = 'Continue'
        }
    }

    process {
        Write-Debug $Message
    }

    end {
        $DebugPreference = $oldDebugPreference
    }
}

# Importing from [C:\git\JiraPS\JiraPS\Public]
# .\JiraPS\Public\Add-JiraGroupMember.ps1
function Add-JiraGroupMember {
    [CmdletBinding( SupportsShouldProcess )]
    param(
        [Parameter( Mandatory, ValueFromPipeline )]
        [Alias('GroupName')]
        [Object[]]
        $Group,

        [Parameter( Mandatory )]
        [Object[]]
        $UserName,
        <#
          #ToDo:CustomClass
          Once we have custom classes, this can also accept ValueFromPipeline
        #>

        [PSCredential]
        $Credential,

        [Switch]
        $PassThru
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"

        $server = Get-JiraConfigServer -ErrorAction Stop

        $resourceURi = "$server/rest/api/latest/group/user?groupname={0}"
    }

    process {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] ParameterSetName: $($PsCmdlet.ParameterSetName)"
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] PSBoundParameters: $($PSBoundParameters | Out-String)"

        foreach ($_group in $Group) {
            Write-Verbose "[$($MyInvocation.MyCommand.Name)] Processing [$_group]"
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Processing `$_group [$_group]"

            $groupObj = Get-JiraGroup -GroupName $_group -Credential $Credential -ErrorAction Stop
            $groupMembers = (Get-JiraGroupMember -Group $_group -Credential $Credential -ErrorAction Stop).Name

            # At present, it looks like this REST method doesn't support arrays in the Name property...
            # in other words, a single REST call can only add a single group member to a single group.

            # That's kind of annoying.

            # Anyway, this builds a bunch of individual JSON strings with each username in its own Web
            # request, which we'll loop through again in the Process block.
            $users = Get-JiraUser -UserName $UserName -Credential $Credential
            foreach ($user in $users) {

                if ($groupMembers -notcontains $user.Name) {
                    Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] User [$($user.Name)] is not already in group [$_group]. Adding user."

                    $parameter = @{
                        URI        = $resourceURi -f $groupObj.Name
                        Method     = "POST"
                        Body       = ConvertTo-Json -InputObject @{ 'name' = $user.Name }
                        Credential = $Credential
                    }
                    Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
                    if ($PSCmdlet.ShouldProcess($GroupName, "Adding user '$($user.Name)'.")) {
                        $result = Invoke-JiraMethod @parameter
                    }
                }
                else {
                    $errorMessage = @{
                        Category         = "ResourceExists"
                        CategoryActivity = "Adding [$user] to [$_group]"
                        Message          = "User [$user] is already a member of group [$_group]"
                    }
                    Write-Error @errorMessage
                }
            }

            if ($PassThru) {
                Write-Output (ConvertTo-JiraGroup -InputObject $result)
            }
        }
    }

    end {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}

# .\JiraPS\Public\Add-JiraIssueAttachment.ps1
function Add-JiraIssueAttachment {
    [CmdletBinding( SupportsShouldProcess )]
    param(
        [Parameter( Mandatory )]
        [ValidateNotNullOrEmpty()]
        [ValidateScript(
            {
                if (("JiraPS.Issue" -notin $_.PSObject.TypeNames) -and (($_ -isnot [String]))) {
                    $errorItem = [System.Management.Automation.ErrorRecord]::new(
                        ([System.ArgumentException]"Invalid Type for Parameter"),
                        'ParameterType.NotJiraIssue',
                        [System.Management.Automation.ErrorCategory]::InvalidArgument,
                        $_
                    )
                    $errorItem.ErrorDetails = "Wrong object type provided for Issue. Expected [JiraPS.Issue] or [String], but was $($_.GetType().Name)"
                    $PSCmdlet.ThrowTerminatingError($errorItem)
                    <#
                      #ToDo:CustomClass
                      Once we have custom classes, this check can be done with Type declaration
                    #>
                }
                else {
                    return $true
                }
            }
        )]
        [Alias('Key')]
        [Object]
        $Issue,
        <#
          #ToDo:CustomClass
          Once we have custom classes, this can also accept ValueFromPipeline
        #>

        [Parameter( Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName )]
        [ValidateScript(
            {
                if (-not (Test-Path $_ -PathType Leaf)) {
                    $errorItem = [System.Management.Automation.ErrorRecord]::new(
                        ([System.ArgumentException]"File not found"),
                        'ParameterValue.FileNotFound',
                        [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                        $_
                    )
                    $errorItem.ErrorDetails = "No file could be found with the provided path '$_'."
                    $PSCmdlet.ThrowTerminatingError($errorItem)
                }
                else {
                    return $true
                }
            }
        )]
        [Alias('InFile', 'FullName', 'Path')]
        [String[]]
        $FilePath,

        [PSCredential]
        $Credential,

        [Switch]
        $PassThru
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"

        $resourceURi = "{0}/attachments"
    }

    process {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] ParameterSetName: $($PsCmdlet.ParameterSetName)"
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] PSBoundParameters: $($PSBoundParameters | Out-String)"

        if (@($Issue).Count -ne 1) {
            $errorItem = [System.Management.Automation.ErrorRecord]::new(
                ([System.ArgumentException]"invalid Issue provided"),
                'ParameterValue.JiraIssue',
                [System.Management.Automation.ErrorCategory]::InvalidArgument,
                $_
            )
            $errorItem.ErrorDetails = "Only one Issue can be provided at a time."
            $PSCmdlet.ThrowTerminatingError($errorItem)
        }

        # Find the proper object for the Issue
        $issueObj = Resolve-JiraIssueObject -InputObject $Issue -Credential $Credential

        foreach ($file in $FilePath) {
            $fileName = Split-Path -Path $file -Leaf
            $readFile = [System.IO.File]::ReadAllBytes($file)
            $enc = [System.Text.Encoding]::GetEncoding("iso-8859-1")
            $fileEnc = $enc.GetString($readFile)
            $boundary = [System.Guid]::NewGuid().ToString()
            $mimeType = [System.Web.MimeMapping]::GetMimeMapping($file)
            if ($mimeType) { $ContentType = $mimeType }
            else { $ContentType = "application/octet-stream" }

            $bodyLines = @'
--{0}
Content-Disposition: form-data; name="file"; filename="{1}"
Content-Type: {2}

{3}
--{0}--

'@ -f $boundary, $fileName, $mimeType, $fileEnc

            $headers = @{
                'X-Atlassian-Token' = 'nocheck'
                'Content-Type'      = "multipart/form-data; boundary=`"$boundary`""
            }

            $parameter = @{
                URI        = $resourceURi -f $issueObj.RestURL
                Method     = "POST"
                Body       = $bodyLines
                Headers    = $headers
                RawBody    = $true
                Credential = $Credential
            }
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
            if ($PSCmdlet.ShouldProcess($IssueObj.Key, "Adding attachment '$($fileName)'.")) {
                $rawResult = Invoke-JiraMethod @parameter

                if ($PassThru) {
                    Write-Output (ConvertTo-JiraAttachment -InputObject $rawResult)
                }
            }
        }
    }

    end {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}

# .\JiraPS\Public\Add-JiraIssueComment.ps1
function Add-JiraIssueComment {
    [CmdletBinding( SupportsShouldProcess )]
    param(
        [Parameter( Mandatory )]
        [ValidateNotNullOrEmpty()]
        [String]
        $Comment,

        [Parameter( Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName )]
        [ValidateNotNullOrEmpty()]
        [ValidateScript(
            {
                if (("JiraPS.Issue" -notin $_.PSObject.TypeNames) -and (($_ -isnot [String]))) {
                    $errorItem = [System.Management.Automation.ErrorRecord]::new(
                        ([System.ArgumentException]"Invalid Type for Parameter"),
                        'ParameterType.NotJiraIssue',
                        [System.Management.Automation.ErrorCategory]::InvalidArgument,
                        $_
                    )
                    $errorItem.ErrorDetails = "Wrong object type provided for Issue. Expected [JiraPS.Issue] or [String], but was $($_.GetType().Name)"
                    $PSCmdlet.ThrowTerminatingError($errorItem)
                    <#
                      #ToDo:CustomClass
                      Once we have custom classes, this check can be done with Type declaration
                    #>
                }
                else {
                    return $true
                }
            }
        )]
        [Alias('Key')]
        [Object]
        $Issue,

        [ValidateSet('All Users', 'Developers', 'Administrators')]
        [String]
        $VisibleRole = 'All Users',

        [PSCredential]
        $Credential
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"

        $resourceURi = "{0}/comment"
    }

    process {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] ParameterSetName: $($PsCmdlet.ParameterSetName)"
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] PSBoundParameters: $($PSBoundParameters | Out-String)"

        # Find the proper object for the Issue
        $issueObj = Resolve-JiraIssueObject -InputObject $Issue -Credential $Credential

        $requestBody = @{
            'body' = $Comment
        }

        # If the visible role should be all users, the visibility block shouldn't be passed at
        # all. JIRA returns a 500 Internal Server Error if you try to pass this block with a
        # value of "All Users".
        if ($VisibleRole -ne 'All Users') {
            $requestBody.visibility = @{
                'type'  = 'role'
                'value' = $VisibleRole
            }
        }

        $parameter = @{
            URI        = $resourceURi -f $issueObj.RestURL
            Method     = "POST"
            Body       = ConvertTo-Json -InputObject $requestBody
            Credential = $Credential
        }
        Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
        if ($PSCmdlet.ShouldProcess($issueObj.Key)) {
            $rawResult = Invoke-JiraMethod @parameter

            Write-Output (ConvertTo-JiraComment -InputObject $rawResult)
        }
    }

    end {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}

# .\JiraPS\Public\Add-JiraIssueLink.ps1
function Add-JiraIssueLink {
    [CmdletBinding( SupportsShouldProcess )]
    param(
        [Parameter( Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName )]
        [ValidateNotNullOrEmpty()]
        [ValidateScript(
            {
                if (("JiraPS.Issue" -notin $_.PSObject.TypeNames) -and (($_ -isnot [String]))) {
                    $errorItem = [System.Management.Automation.ErrorRecord]::new(
                        ([System.ArgumentException]"Invalid Type for Parameter"),
                        'ParameterType.NotJiraIssue',
                        [System.Management.Automation.ErrorCategory]::InvalidArgument,
                        $_
                    )
                    $errorItem.ErrorDetails = "Wrong object type provided for Issue. Expected [JiraPS.Issue] or [String], but was $($_.GetType().Name)"
                    $PSCmdlet.ThrowTerminatingError($errorItem)
                    <#
                      #ToDo:CustomClass
                      Once we have custom classes, this check can be done with Type declaration
                    #>
                }
                else {
                    return $true
                }
            }
        )]
        [Alias('Key')]
        [Object[]]
        $Issue,

        [Parameter( Mandatory )]
        [ValidateScript(
            {
                $objectProperties = Get-Member -InputObject $_ -MemberType *Property
                if (-not(
                        ($objectProperties.Name -contains "type") -and
                        (($objectProperties.Name -contains "outwardIssue") -or ($objectProperties.Name -contains "inwardIssue"))
                    )) {
                    $errorItem = [System.Management.Automation.ErrorRecord]::new(
                        ([System.ArgumentException]"Invalid Parameter"),
                        'ParameterProperties.Incomplete',
                        [System.Management.Automation.ErrorCategory]::InvalidArgument,
                        $_
                    )
                    $errorItem.ErrorDetails = "The IssueLink provided does not contain the information needed."
                    $PSCmdlet.ThrowTerminatingError($errorItem)
                    <#
                      #ToDo:CustomClass
                      Once we have custom classes, this check can be done with Type declaration
                    #>
                }
                else {
                    return $true
                }
            }
        )]
        [Object[]]
        $IssueLink,

        [String]
        $Comment,

        [PSCredential]
        $Credential
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"

        $server = Get-JiraConfigServer -ErrorAction Stop

        $resourceURi = "$server/rest/api/latest/issueLink"
    }

    process {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] ParameterSetName: $($PsCmdlet.ParameterSetName)"
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] PSBoundParameters: $($PSBoundParameters | Out-String)"

        foreach ($_issue in $Issue) {
            # Find the proper object for the Issue
            $issueObj = Resolve-JiraIssueObject -InputObject $_issue -Credential $Credential

            foreach ($_issueLink in $IssueLink) {
                if ($_issueLink.inwardIssue) {
                    $inwardIssue = @{ key = $_issueLink.inwardIssue.key }
                }
                else {
                    $inwardIssue = @{ key = $issueObj.key }
                }

                if ($_issueLink.outwardIssue) {
                    $outwardIssue = @{ key = $_issueLink.outwardIssue.key }
                }
                else {
                    $outwardIssue = @{ key = $issueObj.key }
                }

                $body = @{
                    type         = @{ name = $_issueLink.type.name }
                    inwardIssue  = $inwardIssue
                    outwardIssue = $outwardIssue
                }

                if ($Comment) {
                    $body.comment = @{ body = $Comment }
                }

                $parameter = @{
                    URI        = $resourceURi
                    Method     = "POST"
                    Body       = ConvertTo-Json -InputObject $body
                    Credential = $Credential
                }
                Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
                if ($PSCmdlet.ShouldProcess($issueObj.Key)) {
                    Invoke-JiraMethod @parameter
                }
            }
        }
    }

    end {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}

# .\JiraPS\Public\Add-JiraIssueWatcher.ps1
function Add-JiraIssueWatcher {
    [CmdletBinding( SupportsShouldProcess )]
    param(
        [Parameter( Mandatory )]
        [String[]]
        $Watcher,
        <#
          #ToDo:CustomClass
          Once we have custom classes, this can also accept ValueFromPipeline
        #>

        [Parameter( Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName )]
        [ValidateNotNullOrEmpty()]
        [ValidateScript(
            {
                if (("JiraPS.Issue" -notin $_.PSObject.TypeNames) -and (($_ -isnot [String]))) {
                    $errorItem = [System.Management.Automation.ErrorRecord]::new(
                        ([System.ArgumentException]"Invalid Type for Parameter"),
                        'ParameterType.NotJiraIssue',
                        [System.Management.Automation.ErrorCategory]::InvalidArgument,
                        $_
                    )
                    $errorItem.ErrorDetails = "Wrong object type provided for Issue. Expected [JiraPS.Issue] or [String], but was $($_.GetType().Name)"
                    $PSCmdlet.ThrowTerminatingError($errorItem)
                    <#
                      #ToDo:CustomClass
                      Once we have custom classes, this check can be done with Type declaration
                    #>
                }
                else {
                    return $true
                }
            }
        )]
        [Alias('Key')]
        [Object]
        $Issue,

        [PSCredential]
        $Credential
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"

        $resourceURi = "{0}/watchers"
    }

    process {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] ParameterSetName: $($PsCmdlet.ParameterSetName)"
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] PSBoundParameters: $($PSBoundParameters | Out-String)"

        # Find the proper object for the Issue
        $issueObj = Resolve-JiraIssueObject -InputObject $Issue -Credential $Credential

        foreach ($_watcher in $Watcher) {
            Write-Verbose "[$($MyInvocation.MyCommand.Name)] Processing [$_watcher]"
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Processing `$_watcher [$_watcher]"

            $parameter = @{
                URI        = $resourceURi -f $issueObj.RestURL
                Method     = "POST"
                Body       = '"{0}"' -f $_watcher
                Credential = $Credential
            }
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
            if ($PSCmdlet.ShouldProcess($issueObj.Key, "Adding user '$_watcher' as watcher.")) {
                Invoke-JiraMethod @parameter
            }
        }
    }

    end {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}

# .\JiraPS\Public\Add-JiraIssueWorklog.ps1
function Add-JiraIssueWorklog {
    [CmdletBinding( SupportsShouldProcess )]
    param(
        [Parameter( Mandatory )]
        [ValidateNotNullOrEmpty()]
        [String]
        $Comment,

        [Parameter( Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName )]
        [ValidateNotNullOrEmpty()]
        [ValidateScript(
            {
                if (("JiraPS.Issue" -notin $_.PSObject.TypeNames) -and (($_ -isnot [String]))) {
                    $errorItem = [System.Management.Automation.ErrorRecord]::new(
                        ([System.ArgumentException]"Invalid Type for Parameter"),
                        'ParameterType.NotJiraIssue',
                        [System.Management.Automation.ErrorCategory]::InvalidArgument,
                        $_
                    )
                    $errorItem.ErrorDetails = "Wrong object type provided for Issue. Expected [JiraPS.Issue] or [String], but was $($_.GetType().Name)"
                    $PSCmdlet.ThrowTerminatingError($errorItem)
                    <#
                      #ToDo:CustomClass
                      Once we have custom classes, this check can be done with Type declaration
                    #>
                }
                else {
                    return $true
                }
            }
        )]
        [Alias('Key')]
        [Object]
        $Issue,

        [Parameter( Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName )]
        [TimeSpan]
        $TimeSpent,

        [Parameter( Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName )]
        [DateTime]
        $DateStarted,

        [ValidateSet('All Users', 'Developers', 'Administrators')]
        [String]
        $VisibleRole = 'All Users',

        [PSCredential]
        $Credential
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"

        $resourceURi = "{0}/worklog"
    }

    process {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] ParameterSetName: $($PsCmdlet.ParameterSetName)"
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] PSBoundParameters: $($PSBoundParameters | Out-String)"

        # Find the proper object for the Issue
        $issueObj = Resolve-JiraIssueObject -InputObject $Issue -Credential $Credential

        if (-not $issueObj) {
            $errorMessage = @{
                Category         = "ObjectNotFound"
                CategoryActivity = "Searching for Issue"
                Message          = "Invalid Issue provided."
            }
            Write-Error @errorMessage
        }

        $requestBody = @{
            'comment'          = $Comment
            # We need to fix the date with a RegEx replace because the API does not like:
            # * miliseconds with more than 3 digits
            # * `:` in the TimeZone
            'started'          = $DateStarted.ToString("o") -replace "\.(\d{3})\d*([\+\-]\d{2}):", ".`$1`$2"
            'timeSpentSeconds' = $TimeSpent.TotalSeconds.ToString()
        }

        # If the visible role should be all users, the visibility block shouldn't be passed at
        # all. JIRA returns a 500 Internal Server Error if you try to pass this block with a
        # value of "All Users".
        if ($VisibleRole -ne 'All Users') {
            $requestBody.visibility = @{
                'type'  = 'role'
                'value' = $VisibleRole
            }
        }

        $parameter = @{
            URI        = $resourceURi -f $issueObj.RestURL
            Method     = "POST"
            Body       = ConvertTo-Json -InputObject $requestBody
            Credential = $Credential
        }
        Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
        if ($PSCmdlet.ShouldProcess($issueObj.Key)) {
            $result = Invoke-JiraMethod @parameter

            Write-Output (ConvertTo-JiraWorklogitem -InputObject $result)
        }
    }

    end {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}

# .\JiraPS\Public\Format-Jira.ps1
function Format-Jira {
    [CmdletBinding()]
    [OutputType([System.String])]
    param(
        [Parameter( Mandatory, ValueFromPipeline, ValueFromRemainingArguments )]
        [ValidateNotNull()]
        [PSObject[]]
        $InputObject,

        [Object[]]
        $Property
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"

        $headers = New-Object -TypeName System.Collections.ArrayList
        $thisLine = New-Object -TypeName System.Text.StringBuilder
        $allText = New-Object -TypeName System.Text.StringBuilder

        $headerDefined = $false

        $n = [System.Environment]::NewLine

        if ($Property) {
            if ($Property -eq '*') {
                Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] -Property * was passed. Adding all properties."
            }
            else {

                foreach ($p in $Property) {
                    Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] Adding header [$p]"
                    [void] $headers.Add($p.ToString())
                }

                $headerString = "||$(($headers.ToArray()) -join '||')||"
                Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] Full header: [$headerString]"
                [void] $allText.Append($headerString)
                $headerDefined = $true
            }
        }
        else {
            Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] Property parameter was not specified. Checking first InputObject for property names."
        }
    }

    process {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] ParameterSetName: $($PsCmdlet.ParameterSetName)"
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] PSBoundParameters: $($PSBoundParameters | Out-String)"

        foreach ($i in $InputObject) {
            if (-not ($headerDefined)) {
                # This should only be called if Property was not supplied and this is the first object in the InputObject array.
                if ($Property -and $Property -eq '*') {
                    Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] Adding all properties from object [$i]"
                    $allProperties = Get-Member -InputObject $i -MemberType '*Property'
                    foreach ($a in $allProperties) {
                        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] Adding header [$($a.Name)]"
                        [void] $headers.Add($a.Name)
                    }
                }
                else {

                    # TODO: find a way to format output objects based on PowerShell's own Format-Table
                    # Identify default table properties if possible and use them to create a Jira table

                    if ($i.PSStandardMembers.DefaultDisplayPropertySet) {
                        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] Identifying default properties for object [$i]"
                        $propertyNames = $i.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames
                        foreach ($p in $propertyNames) {
                            Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] Adding header [$p]"
                            [void] $headers.Add($p)
                        }
                    }
                    else {
                        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] No default format data exists for object [$i] (type=[$($i.GetType())]). All properties will be used."
                        $allProperties = Get-Member -InputObject $i -MemberType '*Property'
                        foreach ($a in $allProperties) {
                            Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] Adding header [$($a.Name)]"
                            [void] $headers.Add($a.Name)
                        }
                    }
                }

                $headerString = "||$(($headers.ToArray()) -join '||')||"
                Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] Full header: [$headerString]"
                [void] $allText.Append($headerString)
                $headerDefined = $true
            }

            Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] Processing object [$i]"
            [void] $thisLine.Clear()
            [void] $thisLine.Append("$n|")

            foreach ($h in $headers) {
                $value = $InputObject.$h
                if ($value) {
                    Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] Adding property (name=[$h], value=[$value])"
                    [void] $thisLine.Append("$value|")
                }
                else {
                    Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] Property [$h] does not exist on this object."
                    [void] $thisLine.Append(' |')
                }
            }

            $thisLineString = $thisLine.ToString()
            Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] Completed line: [$thisLineString]"
            [void] $allText.Append($thisLineString)
        }
    }

    end {
        Write-Output $allText.ToString()

        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}

# .\JiraPS\Public\Get-JiraComponent.ps1
function Get-JiraComponent {
    [CmdletBinding(DefaultParameterSetName = 'ByID')]
    param(
        [Parameter( Position = 0, Mandatory, ValueFromPipeline, ParameterSetName = 'ByProject' )]
        [ValidateNotNullOrEmpty()]
        [ValidateScript(
            {
                if (("JiraPS.Project" -notin $_.PSObject.TypeNames) -and (($_ -isnot [String]))) {
                    $errorItem = [System.Management.Automation.ErrorRecord]::new(
                        ([System.ArgumentException]"Invalid Type for Parameter"),
                        'ParameterType.NotJiraProject',
                        [System.Management.Automation.ErrorCategory]::InvalidArgument,
                        $_
                    )
                    $errorItem.ErrorDetails = "Wrong object type provided for Issue. Expected [JiraPS.Project] or [String], but was $($_.GetType().Name)"
                    $PSCmdlet.ThrowTerminatingError($errorItem)
                    <#
                      #ToDo:CustomClass
                      Once we have custom classes, this check can be done with Type declaration
                    #>
                }
                else {
                    return $true
                }
            }
        )]
        [Object[]]
        $Project,
        <#
          #ToDo:CustomClass
          Once we have custom classes, these two parameters can be one
        #>

        [Parameter( Position = 0, Mandatory, ParameterSetName = 'ByID' )]
        [Alias("Id")]
        [Int[]]
        $ComponentId,

        [PSCredential]
        $Credential
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"

        $server = Get-JiraConfigServer -ErrorAction Stop

        $resourceURi = "$server/rest/api/latest{0}"
    }

    process {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] ParameterSetName: $($PsCmdlet.ParameterSetName)"
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] PSBoundParameters: $($PSBoundParameters | Out-String)"

        switch ($PSCmdlet.ParameterSetName) {
            "ByProject" {
                if ($Project.PSObject.TypeNames -contains 'JiraPS.Project') {
                    Write-Output (Get-JiraComponent -ComponentId ($Project.Components).id)
                }
                else {
                    foreach ($_project in $Project) {
                        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Processing [$_project]"
                        Write-Debug "[$($MyInvocation.MyCommand.Name)] Processing `$_project [$_project]"

                        if ($_project -is [string]) {
                            $parameter = @{
                                URI        = $resourceURi -f "/project/$_project/components"
                                Method     = "GET"
                                Credential = $Credential
                            }
                            Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
                            $result = Invoke-JiraMethod @parameter

                            Write-Output (ConvertTo-JiraComponent -InputObject $result)
                        }
                    }
                }
            }
            "ByID" {
                foreach ($_id in $ComponentId) {
                    Write-Verbose "[$($MyInvocation.MyCommand.Name)] Processing [$_id]"
                    Write-Debug "[$($MyInvocation.MyCommand.Name)] Processing `$_id [$_id]"

                    $parameter = @{
                        URI        = $resourceURi -f "/component/$_id"
                        Method     = "GET"
                        Credential = $Credential
                    }
                    Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
                    $result = Invoke-JiraMethod @parameter

                    Write-Output (ConvertTo-JiraComponent -InputObject $result)
                }
            }
        }
    }

    end {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}

# .\JiraPS\Public\Get-JiraConfigServer.ps1
function Get-JiraConfigServer {
    [CmdletBinding()]
    [OutputType([System.String])]
    param(
        [String]
        $ConfigFile
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"
    }

    process {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] ParameterSetName: $($PsCmdlet.ParameterSetName)"
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] PSBoundParameters: $($PSBoundParameters | Out-String)"

        # Using a default value for this parameter wouldn't handle all cases. We want to make sure
        # that the user can pass a $null value to the ConfigFile parameter...but if it's null, we
        # want to default to the script variable just as we would if the parameter was not
        # provided at all.

        if (-not ($ConfigFile)) {
            # This file should be in $moduleRoot/Functions/Internal, so PSScriptRoot will be $moduleRoot/Functions
            $moduleFolder = Split-Path -Path $PSScriptRoot -Parent
            $ConfigFile = Join-Path -Path $moduleFolder -ChildPath 'config.xml'
        }

        if (-not (Test-Path -Path $ConfigFile)) {
            $errorItem = [System.Management.Automation.ErrorRecord]::new(
                ([System.IO.FileNotFoundException]"Could not find $ConfigFile"),
                'ConfigFile.NotFound',
                [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                $ConfigFile
            )
            $errorItem.ErrorDetails = "Config file [$ConfigFile] does not exist. Use Set-JiraConfigServer first to define the configuration file."
            $PSCmdlet.ThrowTerminatingError($errorItem)
        }

        Write-Debug "Loading config file `$ConfigFile [$ConfigFile]"
        $xml = New-Object -TypeName XML
        $xml.Load($ConfigFile)

        $xmlConfig = $xml.DocumentElement
        if ($xmlConfig.LocalName -ne 'Config') {
            $errorItem = [System.Management.Automation.ErrorRecord]::new(
                ([System.IO.FileFormatException]"XML had not the expected format"),
                'ConfigFile.UnexpectedElement',
                [System.Management.Automation.ErrorCategory]::ParserError,
                $ConfigFile
            )
            $errorItem.ErrorDetails = "Unexpected document element [$($xmlConfig.LocalName)] in configuration file [$ConfigFile]. You may need to delete the config file and recreate it using Set-JiraConfigServer."
            $PSCmdlet.ThrowTerminatingError($errorItem)
        }

        if ($xmlConfig.Server) {
            Write-Output $xmlConfig.Server
        }
        else {
            $errorItem = [System.Management.Automation.ErrorRecord]::new(
                ([System.UriFormatException]"Could not find URI"),
                'ConfigFile.EmptyElement',
                [System.Management.Automation.ErrorCategory]::OpenError,
                $ConfigFile
            )
            $errorItem.ErrorDetails = "No Server element is defined in the config file.  Use Set-JiraConfigServer to define one."
            $PSCmdlet.ThrowTerminatingError($errorItem)
        }
    }

    end {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}

# .\JiraPS\Public\Get-JiraField.ps1
function Get-JiraField {
    [CmdletBinding( DefaultParameterSetName = '_All' )]
    param(
        [Parameter( Position = 0, Mandatory, ValueFromPipeline, ParameterSetName = '_Search' )]
        [String[]]
        $Field,

        [PSCredential]
        $Credential
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"

        $server = Get-JiraConfigServer -ErrorAction Stop

        $resourceURi = "$server/rest/api/latest/field"
    }

    process {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] ParameterSetName: $($PsCmdlet.ParameterSetName)"
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] PSBoundParameters: $($PSBoundParameters | Out-String)"

        switch ($PSCmdlet.ParameterSetName) {
            '_All' {
                $parameter = @{
                    URI        = $resourceURi
                    Method     = "GET"
                    Credential = $Credential
                }
                Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
                $result = Invoke-JiraMethod @parameter

                Write-Output (ConvertTo-JiraField -InputObject $result)
            }
            '_Search' {
                foreach ($_field in $Field) {
                    Write-Verbose "[$($MyInvocation.MyCommand.Name)] Processing [$_field]"
                    Write-Debug "[$($MyInvocation.MyCommand.Name)] Processing `$_field [$_field]"

                    $allFields = Get-JiraField -Credential $Credential

                    Write-Output ($allFields | Where-Object -FilterScript {($_.Id -eq $_field) -or ($_.Name -like $_field)})
                }
            }
        }
    }

    end {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}

# .\JiraPS\Public\Get-JiraFilter.ps1
function Get-JiraFilter {
    [CmdletBinding(DefaultParameterSetName = 'ByFilterID')]
    param(
        [Parameter( Position = 0, Mandatory, ParameterSetName = 'ByFilterID' )]
        [String[]]
        $Id,
        <#
          #ToDo:CustomClass
          Once we have custom classes for the module,
          this can use ValueFromPipelineByPropertyName
          and we will no longer need the InputObject
        #>

        [Parameter( Mandatory, ValueFromPipeline, ParameterSetName = 'ByInputObject' )]
        [ValidateNotNullOrEmpty()]
        [ValidateScript(
            {
                if (("JiraPS.Filter" -notin $_.PSObject.TypeNames) -and (($_ -isnot [String]))) {
                    $errorItem = [System.Management.Automation.ErrorRecord]::new(
                        ([System.ArgumentException]"Invalid Type for Parameter"),
                        'ParameterType.NotJiraFilter',
                        [System.Management.Automation.ErrorCategory]::InvalidArgument,
                        $_
                    )
                    $errorItem.ErrorDetails = "Wrong object type provided for Filter. Expected [JiraPS.Filter] or [String], but was $($_.GetType().Name)"
                    $PSCmdlet.ThrowTerminatingError($errorItem)
                    <#
                      #ToDo:CustomClass
                      Once we have custom classes, this check can be done with Type declaration
                    #>
                }
                else {
                    return $true
                }
            }
        )]
        [Object[]]
        $InputObject,

        [PSCredential]
        $Credential
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"

        $server = Get-JiraConfigServer -ErrorAction Stop

        $resourceURi = "$server/rest/api/latest/filter/{0}"
    }

    process {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] ParameterSetName: $($PsCmdlet.ParameterSetName)"
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] PSBoundParameters: $($PSBoundParameters | Out-String)"

        switch ($PSCmdlet.ParameterSetName) {
            "ByFilterID" {
                foreach ($_id in $Id) {
                    Write-Verbose "[$($MyInvocation.MyCommand.Name)] Processing [$_id]"
                    Write-Debug "[$($MyInvocation.MyCommand.Name)] Processing `$_id [$_id]"

                    $parameter = @{
                        URI        = $resourceURi -f $_id
                        Method     = "GET"
                        Credential = $Credential
                    }
                    Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
                    $result = Invoke-JiraMethod @parameter

                    Write-Output (ConvertTo-JiraFilter -InputObject $result)
                }
            }
            "ByInputObject" {
                foreach ($object in $InputObject) {
                    Write-Verbose "[$($MyInvocation.MyCommand.Name)] Processing [$object]"
                    Write-Debug "[$($MyInvocation.MyCommand.Name)] Processing `$object [$object]"

                    if ((Get-Member -InputObject $object).TypeName -eq 'JiraPS.Filter') {
                        $thisId = $object.ID
                    }
                    else {
                        $thisId = $object.ToString()
                        Write-Verbose "[$($MyInvocation.MyCommand.Name)] ID is assumed to be [$thisId] via ToString()"
                    }

                    Write-Output (Get-JiraFilter -Id $thisId -Credential $Credential)
                }
            }
        }
    }

    end {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}

# .\JiraPS\Public\Get-JiraGroup.ps1
function Get-JiraGroup {
    [CmdletBinding()]
    param(
        [Parameter( Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName )]
        [ValidateNotNullOrEmpty()]
        [Alias('Name')]
        [String[]]
        $GroupName,

        [PSCredential]
        $Credential
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"

        $server = Get-JiraConfigServer -ErrorAction Stop

        $resourceURi = "$server/rest/api/latest/group?groupname={0}"
    }

    process {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] ParameterSetName: $($PsCmdlet.ParameterSetName)"
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] PSBoundParameters: $($PSBoundParameters | Out-String)"

        foreach ($group in $GroupName) {
            Write-Verbose "[$($MyInvocation.MyCommand.Name)] Processing [$group]"
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Processing `$group [$group]"

            $escapedGroupName = ConvertTo-URLEncoded $group

            $parameter = @{
                URI        = $resourceURi -f $escapedGroupName
                Method     = "GET"
                Credential = $Credential
            }
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
            $result = Invoke-JiraMethod @parameter

            Write-Output (ConvertTo-JiraGroup -InputObject $result)
        }
    }

    end {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}

# .\JiraPS\Public\Get-JiraGroupMember.ps1
function Get-JiraGroupMember {
    [CmdletBinding()]
    param(
        [Parameter( Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName )]
        [ValidateNotNullOrEmpty()]
        [ValidateScript(
            {
                if (("JiraPS.Group" -notin $_.PSObject.TypeNames) -and (($_ -isnot [String]))) {
                    $errorItem = [System.Management.Automation.ErrorRecord]::new(
                        ([System.ArgumentException]"Invalid Type for Parameter"),
                        'ParameterType.NotJiraGroup',
                        [System.Management.Automation.ErrorCategory]::InvalidArgument,
                        $_
                    )
                    $errorItem.ErrorDetails = "Wrong object type provided for Group. Expected [JiraPS.Group] or [String], but was $($_.GetType().Name)"
                    $PSCmdlet.ThrowTerminatingError($errorItem)
                    <#
                      #ToDo:CustomClass
                      Once we have custom classes, this check can be done with Type declaration
                    #>
                }
                else {
                    return $true
                }
            }
        )]
        [Object[]]
        $Group,

        [ValidateRange(0, [Int]::MaxValue)]
        [Int]
        $StartIndex = 0,

        [ValidateRange(0, [Int]::MaxValue)]
        [Int]
        $MaxResults = 0,

        [PSCredential]
        $Credential
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"

        # This is a parameter in Get-JiraIssue, but in testing, JIRA doesn't
        # reliably return more than 50 results at a time.
        $pageSize = 50

        if ($MaxResults -eq 0) {
            Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] MaxResults was not specified. Using loop mode to obtain all members."
            $loopMode = $true
        }
        else {
            $loopMode = $false
            if ($MaxResults -gt 50) {
                Write-Warning "JIRA's API may not properly support MaxResults values higher than 50 for this method. If you receive inconsistent results, do not pass the MaxResults parameter to this function to return all results."
            }
        }
    }

    process {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] ParameterSetName: $($PsCmdlet.ParameterSetName)"
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] PSBoundParameters: $($PSBoundParameters | Out-String)"

        $groupObj = Get-JiraGroup -GroupName $Group -Credential $Credential -ErrorAction Stop

        foreach ($_group in $groupObj) {
            Write-Verbose "[$($MyInvocation.MyCommand.Name)] Processing [$_group]"
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Processing `$_group [$_group]"

            if ($loopMode) {
                # Using the Size property of the group object, iterate
                # through all users in a given group.

                $totalResults = $_group.Size
                $allUsers = New-Object -TypeName System.Collections.ArrayList

                for ($i = 0; $i -lt $totalResults; $i = $i + $PageSize) {
                    if ($PageSize -gt ($i + $totalResults)) {
                        $thisPageSize = $totalResults - $i
                    }
                    else {
                        $thisPageSize = $PageSize
                    }
                    $percentComplete = ($i / $totalResults) * 100
                    Write-Progress -Activity "$($MyInvocation.MyCommand.Name)" -Status "Obtaining members ($i - $($i + $thisPageSize) of $totalResults)..." -PercentComplete $percentComplete

                    Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] Obtaining members $i - $($i + $thisPageSize)..."
                    $thisSection = Get-JiraGroupMember -Group $_group -StartIndex $i -MaxResults $thisPageSize -Credential $Credential

                    foreach ($_user in $thisSection) {
                        [void] $allUsers.Add($_user)
                    }
                }

                Write-Progress -Activity "$($MyInvocation.MyCommand.Name)" -Completed
                Write-Output ($allUsers.ToArray())
            }
            else {
                # Since user is an expandable property of the returned
                # group from JIRA, JIRA doesn't use the MaxResults argument
                # found in other REST endpoints.  Instead, we need to pass
                # expand=users[0:15] for users 0-15 (inclusive).
                $parameter = @{
                    URI        = '{0}&expand=users[{1}:{2}]' -f $_group.RestUrl, $StartIndex, ($StartIndex + $MaxResults)
                    Method     = "GET"
                    Credential = $Credential
                }
                Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
                $result = Invoke-JiraMethod @parameter

                Write-Output (ConvertTo-JiraGroup -InputObject $result).Member
            }
        }
    }

    end {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}

# .\JiraPS\Public\Get-JiraIssue.ps1
function Get-JiraIssue {
    [CmdletBinding(DefaultParameterSetName = 'ByIssueKey')]
    param(
        [Parameter( Position = 0, Mandatory, ParameterSetName = 'ByIssueKey' )]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $Key,

        [Parameter( Position = 0, Mandatory, ParameterSetName = 'ByInputObject' )]
        [ValidateNotNullOrEmpty()]
        [ValidateScript(
            {
                if (("JiraPS.Issue" -notin $_.PSObject.TypeNames) -and (($_ -isnot [String]))) {
                    $errorItem = [System.Management.Automation.ErrorRecord]::new(
                        ([System.ArgumentException]"Invalid Type for Parameter"),
                        'ParameterType.NotJiraIssue',
                        [System.Management.Automation.ErrorCategory]::InvalidArgument,
                        $_
                    )
                    $errorItem.ErrorDetails = "Wrong object type provided for Issue. Expected [JiraPS.Issue] or [String], but was $($_.GetType().Name)"
                    $PSCmdlet.ThrowTerminatingError($errorItem)
                }
                else {
                    return $true
                }
            }
        )]
        [Object[]]
        $InputObject,
        <#
          #ToDo:Deprecate
          This is not necessary if $Key uses ValueFromPipelineByPropertyName
          #ToDo:CustomClass
          Once we have custom classes, this check can be done with Type declaration
        #>

        [Parameter( Mandatory, ParameterSetName = 'ByJQL' )]
        [Alias('JQL')]
        [String]
        $Query,

        [Parameter( Mandatory, ParameterSetName = 'ByFilter' )]
        [ValidateNotNullOrEmpty()]
        [ValidateScript(
            {
                if (("JiraPS.Filter" -notin $_.PSObject.TypeNames) -and (($_ -isnot [String]))) {
                    $errorItem = [System.Management.Automation.ErrorRecord]::new(
                        ([System.ArgumentException]"Invalid Type for Parameter"),
                        'ParameterType.NotJiraFilter',
                        [System.Management.Automation.ErrorCategory]::InvalidArgument,
                        $_
                    )
                    $errorItem.ErrorDetails = "Wrong object type provided for Filter. Expected [JiraPS.Filter] or [String], but was $($_.GetType().Name)"
                    $PSCmdlet.ThrowTerminatingError($errorItem)
                    <#
                      #ToDo:CustomClass
                      Once we have custom classes, this check can be done with Type declaration
                    #>
                }
                else {
                    return $true
                }
            }
        )]
        [Object]
        $Filter,

        [Parameter( ParameterSetName = 'ByJQL' )]
        [Parameter( ParameterSetName = 'ByFilter' )]
        [Int]
        $StartIndex = 0,

        [Parameter( ParameterSetName = 'ByJQL' )]
        [Parameter( ParameterSetName = 'ByFilter' )]
        [Int]
        $MaxResults = 0,

        [Parameter( ParameterSetName = 'ByJQL' )]
        [Parameter( ParameterSetName = 'ByFilter' )]
        [Int]
        $PageSize = 50,

        [PSCredential]
        $Credential
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"

        $server = Get-JiraConfigServer -ErrorAction Stop

        if (($PSCmdlet.ParameterSetName -in @('ByJQL', 'ByFilter')) -and $MaxResults -eq 0) {
            Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] Using loop mode to obtain all results"
            $MaxResults = 1
            $loopMode = $true
        }
        else {
            $loopMode = $false
        }

        $resourceURi = "$server/rest/api/latest/issue/{0}?expand=transitions"
        $searchURi = "$server/rest/api/latest/search?jql={0}&validateQuery=true&expand=transitions&startAt={1}&maxResults={2}"
    }

    process {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] ParameterSetName: $($PsCmdlet.ParameterSetName)"
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] PSBoundParameters: $($PSBoundParameters | Out-String)"

        switch ($PSCmdlet.ParameterSetName) {
            'ByIssueKey' {
                foreach ($_key in $Key) {
                    Write-Verbose "[$($MyInvocation.MyCommand.Name)] Processing [$_key]"
                    Write-Debug "[$($MyInvocation.MyCommand.Name)] Processing `$_key [$_key]"

                    $parameter = @{
                        URI        = $resourceURi -f $_key
                        Method     = "GET"
                        Credential = $Credential
                    }
                    Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
                    $result = Invoke-JiraMethod @parameter

                    Write-Output (ConvertTo-JiraIssue -InputObject $result)
                }
            }
            'ByInputObject' {
                # Write-Warning "[$($MyInvocation.MyCommand.Name)] The parameter '-InputObject' has been marked as deprecated."
                foreach ($_issue in $InputObject) {
                    Write-Verbose "[$($MyInvocation.MyCommand.Name)] Processing [$_issue]"
                    Write-Debug "[$($MyInvocation.MyCommand.Name)] Processing `$_issue [$_issue]"

                    Write-Output (Get-JiraIssue -Key $_issue.Key -Credential $Credential)
                }
            }
            'ByJQL' {
                $escapedQuery = ConvertTo-URLEncoded $Query

                $parameter = @{
                    URI        = $searchURi -f $escapedQuery, $StartIndex, $MaxResults
                    Method     = "GET"
                    Credential = $Credential
                }
                Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
                $result = Invoke-JiraMethod @parameter

                if ($result) {
                    # {"startAt":0,"maxResults":50,"total":0,"issues":[]}

                    if ($loopMode) {
                        $totalResults = $result.total

                        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] Paging through all issues (loop mode)"
                        $allIssues = New-Object -TypeName System.Collections.ArrayList

                        for ($i = 0; $i -lt $totalResults; $i = $i + $PageSize) {
                            $percentComplete = ($i / $totalResults) * 100
                            Write-Progress -Activity "$($MyInvocation.MyCommand.Name)" -Status "Obtaining issues ($i - $($i + $PageSize))..." -PercentComplete $percentComplete

                            Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] Obtaining issues $i - $($i + $PageSize)..."
                            $thisSection = Get-JiraIssue -Query $Query -StartIndex $i -MaxResults $PageSize -Credential $Credential

                            foreach ($t in $thisSection) {
                                [void] $allIssues.Add($t)
                            }
                        }
                        Write-Progress -Activity "$($MyInvocation.MyCommand.Name)" -Status 'Obtaining issues' -Completed
                        Write-Output ($allIssues.ToArray())
                    }
                    elseif ($result.total -gt 0) {
                        Write-Output (ConvertTo-JiraIssue -InputObject $result.issues)
                    }
                    else {
                        $errorMessage = @{
                            Category         = "ObjectNotFound"
                            CategoryActivity = "Searching for resource"
                            Message          = "The JQL query did not return any results"
                        }
                        Write-Error @errorMessage
                    }
                }
            }
            'ByFilter' {
                $filterObj = Get-JiraFilter -InputObject $Filter -Credential $Credential -ErrorAction Stop
                $jql = $filterObj.JQL
                <#
                  #ToDo:CustomClass
                  Once we have custom classes, this will no longer be necessary
                #>

                # MaxResults would have been set to 1 in the Begin block if it
                # was not supplied as a parameter. We don't want to explicitly
                # invoke this method recursively with a MaxResults value of 1
                # if it wasn't initially provided to us.
                if ($loopMode) {
                    Write-Output (Get-JiraIssue -Query $jql -Credential $Credential)
                }
                else {
                    Write-Output (Get-JiraIssue -Query $jql -Credential $Credential -MaxResults $MaxResults)
                }
            }
        }
    }

    end {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}

# .\JiraPS\Public\Get-JiraIssueAttachment.ps1
function Get-JiraIssueAttachment {
    [CmdletBinding()]
    param(
        [Parameter( Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName )]
        [ValidateNotNullOrEmpty()]
        [ValidateScript(
            {
                if (("JiraPS.Issue" -notin $_.PSObject.TypeNames) -and (($_ -isnot [String]))) {
                    $errorItem = [System.Management.Automation.ErrorRecord]::new(
                        ([System.ArgumentException]"Invalid Type for Parameter"),
                        'ParameterType.NotJiraIssue',
                        [System.Management.Automation.ErrorCategory]::InvalidArgument,
                        $_
                    )
                    $errorItem.ErrorDetails = "Wrong object type provided for Issue. Expected [JiraPS.Issue] or [String], but was $($_.GetType().Name)"
                    $PSCmdlet.ThrowTerminatingError($errorItem)
                    <#
                      #ToDo:CustomClass
                      Once we have custom classes, this check can be done with Type declaration
                    #>
                }
                else {
                    return $true
                }
            }
        )]
        [Alias('Key')]
        [Object]
        $Issue,

        [String]
        $FileName,

        [PSCredential]
        $Credential
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"
    }

    process {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] ParameterSetName: $($PsCmdlet.ParameterSetName)"
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] PSBoundParameters: $($PSBoundParameters | Out-String)"

        # Find the proper object for the Issue
        $issueObj = Resolve-JiraIssueObject -InputObject $Issue -Credential $Credential

        if ($issueObj.Attachment) {
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Found Attachments on the Issue."
            if ($FileName) {
                $attachments = $issueObj.Attachment | Where-Object {$_.Filename -like $FileName}
            }
            else {
                $attachments = $issueObj.Attachment
            }

            ConvertTo-JiraAttachment -InputObject $attachments
        }
        else {
            $errorMessage = @{
                Category         = "ObjectNotFound"
                CategoryActivity = "Searching for resource"
                Message          = "This issue does not have any attachments"
            }
            Write-Error @errorMessage
        }
    }

    end {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}


# .\JiraPS\Public\Get-JiraIssueComment.ps1
function Get-JiraIssueComment {
    [CmdletBinding()]
    param(
        [Parameter( Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName )]
        [ValidateNotNullOrEmpty()]
        [ValidateScript(
            {
                if (("JiraPS.Issue" -notin $_.PSObject.TypeNames) -and (($_ -isnot [String]))) {
                    $errorItem = [System.Management.Automation.ErrorRecord]::new(
                        ([System.ArgumentException]"Invalid Type for Parameter"),
                        'ParameterType.NotJiraIssue',
                        [System.Management.Automation.ErrorCategory]::InvalidArgument,
                        $_
                    )
                    $errorItem.ErrorDetails = "Wrong object type provided for Issue. Expected [JiraPS.Issue] or [String], but was $($_.GetType().Name)"
                    $PSCmdlet.ThrowTerminatingError($errorItem)
                    <#
                      #ToDo:CustomClass
                      Once we have custom classes, this check can be done with Type declaration
                    #>
                }
                else {
                    return $true
                }
            }
        )]
        [Alias('Key')]
        [Object]
        $Issue,

        [PSCredential]
        $Credential
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"
    }

    process {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] ParameterSetName: $($PsCmdlet.ParameterSetName)"
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] PSBoundParameters: $($PSBoundParameters | Out-String)"

        # Find the proper object for the Issue
        $issueObj = Resolve-JiraIssueObject -InputObject $Issue -Credential $Credential

        $parameter = @{
            URI        = "{0}/comment" -f $issueObj.RestURL
            Method     = "GET"
            Credential = $Credential
        }
        Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
        $result = Invoke-JiraMethod @parameter

        Write-Output (ConvertTo-JiraComment -InputObject $result.comments)
    }

    end {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}

# .\JiraPS\Public\Get-JiraIssueCreateMetadata.ps1
function Get-JiraIssueCreateMetadata {
    [CmdletBinding()]
    param(
        [Parameter( Mandatory )]
        [String]
        $Project,

        [Parameter( Mandatory )]
        [String]
        $IssueType,

        [PSCredential]
        $Credential
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"

        $server = Get-JiraConfigServer -ErrorAction Stop

        $resourceURi = "$server/rest/api/latest/issue/createmeta?projectIds={0}&issuetypeIds={1}&expand=projects.issuetypes.fields"
    }

    process {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] ParameterSetName: $($PsCmdlet.ParameterSetName)"
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] PSBoundParameters: $($PSBoundParameters | Out-String)"

        $projectObj = Get-JiraProject -Project $Project -Credential $Credential -ErrorAction Stop
        $issueTypeObj = Get-JiraIssueType -IssueType $IssueType -Credential $Credential -ErrorAction Stop

        $parameter = @{
            URI        = $resourceURi -f $projectObj.Id, $issueTypeObj.Id
            Method     = "GET"
            Credential = $Credential
        }
        Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
        $result = Invoke-JiraMethod @parameter

        if ($result) {
            if (@($result.projects).Count -eq 0) {
                $errorMessage = @{
                    Category         = "InvalidResult"
                    CategoryActivity = "Validating response"
                    Message          = "No projects were found for the given project [$Project]. Use Get-JiraProject for more details."
                }
                Write-Error @errorMessage
            }
            elseif (@($result.projects).Count -gt 1) {
                $errorMessage = @{
                    Category         = "InvalidResult"
                    CategoryActivity = "Validating response"
                    Message          = "Multiple projects were found for the given project [$Project]. Refine the parameters to return only one project."
                }
                Write-Error @errorMessage
            }

            if (@($result.projects.issuetypes) -eq 0) {
                $errorMessage = @{
                    Category         = "InvalidResult"
                    CategoryActivity = "Validating response"
                    Message          = "No issue types were found for the given issue type [$IssueType]. Use Get-JiraIssueType for more details."
                }
                Write-Error @errorMessage
            }
            elseif (@($result.projects.issuetypes).Count -gt 1) {
                $errorMessage = @{
                    Category         = "InvalidResult"
                    CategoryActivity = "Validating response"
                    Message          = "Multiple issue types were found for the given issue type [$IssueType]. Refine the parameters to return only one issue type."
                }
                Write-Error @errorMessage
            }

            Write-Output (ConvertTo-JiraCreateMetaField -InputObject $result)
        }
        else {
            $errorItem = [System.Management.Automation.ErrorRecord]::new(
                ([System.ArgumentException]"No results"),
                'IssueMetadata.ObjectNotFound',
                [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                $Project
            )
            $errorItem.ErrorDetails = "No metadata found for project $Project and issueType $IssueType."
            Throw $errorItem
        }
    }

    end {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}

# .\JiraPS\Public\Get-JiraIssueEditMetadata.ps1
function Get-JiraIssueEditMetadata {
    [CmdletBinding()]
    param(
        [Parameter( Mandatory )]
        [String]
        $Issue,
        <#
          #ToDo:CustomClass
          Once we have custom classes, this should be a JiraPS.Issue
        #>

        [PSCredential]
        $Credential
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"

        $server = Get-JiraConfigServer -ErrorAction Stop

        $resourceURi = "$server/rest/api/latest/issue/{0}/editmeta"
    }

    process {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] ParameterSetName: $($PsCmdlet.ParameterSetName)"
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] PSBoundParameters: $($PSBoundParameters | Out-String)"

        $parameter = @{
            URI        = $resourceURi -f $Issue
            <#
              #ToDo:CustomClass
              When the Input is typecasted to a JiraPS.Issue, the `self` of the issue can be used
            #>
            Method     = "GET"
            Credential = $Credential
        }
        Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
        $result = Invoke-JiraMethod @parameter

        Write-Debug ($result | Out-String)

        if ($result) {
            if (@($result.fields.projects).Count -eq 0) {
                $errorMessage = @{
                    Category         = "InvalidResult"
                    CategoryActivity = "Validating response"
                    Message          = "No projects were found for the given project [$Project]. Use Get-JiraProject for more details."
                }
                Write-Error @errorMessage
            }
            elseif (@($result.fields.projects).Count -gt 1) {
                $errorMessage = @{
                    Category         = "InvalidResult"
                    CategoryActivity = "Validating response"
                    Message          = "Multiple projects were found for the given project [$Project]. Refine the parameters to return only one project."
                }
                Write-Error @errorMessage
            }

            if (@($result.fields.projects.issuetypes) -eq 0) {
                $errorMessage = @{
                    Category         = "InvalidResult"
                    CategoryActivity = "Validating response"
                    Message          = "No issue types were found for the given issue type [$IssueType]. Use Get-JiraIssueType for more details."
                }
                Write-Error @errorMessage
            }
            elseif (@($result.fields.projects.issuetypes).Count -gt 1) {
                $errorMessage = @{
                    Category         = "InvalidResult"
                    CategoryActivity = "Validating response"
                    Message          = "Multiple issue types were found for the given issue type [$IssueType]. Refine the parameters to return only one issue type."
                }
                Write-Error @errorMessage
            }

            Write-Output (ConvertTo-JiraEditMetaField -InputObject $result)
        }
        else {
            $errorItem = [System.Management.Automation.ErrorRecord]::new(
                ([System.ArgumentException]"No results"),
                'IssueMetadata.ObjectNotFound',
                [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                $Project
            )
            $errorItem.ErrorDetails = "No metadata found for project $Project and issueType $IssueType."
            Throw $errorItem
        }
    }

    end {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}

# .\JiraPS\Public\Get-JiraIssueLink.ps1
function Get-JiraIssueLink {
    [CmdletBinding()]
    param(
        [Parameter( Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName )]
        [Int[]]
        $Id,

        [PSCredential] $Credential
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"

        $server = Get-JiraConfigServer -ErrorAction Stop

        $resourceURi = "$server/rest/api/2/issueLink/{0}"
    }

    process {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] ParameterSetName: $($PsCmdlet.ParameterSetName)"
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] PSBoundParameters: $($PSBoundParameters | Out-String)"

        # Validate input object from Pipeline
        if (($_) -and ("JiraPS.IssueLink" -notin $_.PSObject.TypeNames)) {
            $errorItem = [System.Management.Automation.ErrorRecord]::new(
                ([System.ArgumentException]"Invalid Parameter"),
                'ParameterProperties.WrongObjectType',
                [System.Management.Automation.ErrorCategory]::InvalidArgument,
                $Id
            )
            $errorItem.ErrorDetails = "The IssueLink provided did not match the constraints."
            $PSCmdlet.ThrowTerminatingError($errorItem)
        }

        foreach ($_id in $Id) {
            Write-Verbose "[$($MyInvocation.MyCommand.Name)] Processing [$_id]"
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Processing `$_id [$_id]"

            $parameter = @{
                URI        = $resourceURi -f $_id
                Method     = "GET"
                Credential = $Credential
            }
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
            $result = Invoke-JiraMethod @parameter

            Write-Output (ConvertTo-JiraIssueLink -InputObject $result)
        }
    }

    end {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}

# .\JiraPS\Public\Get-JiraIssueLinkType.ps1
function Get-JiraIssueLinkType {
    [CmdletBinding( DefaultParameterSetName = '_All' )]
    param(
        [Parameter( Position = 0, Mandatory, ParameterSetName = '_Search' )]
        [ValidateNotNullOrEmpty()]
        [ValidateScript(
            {
                if (("JiraPS.IssueLinkType" -notin $_.PSObject.TypeNames) -and (($_ -isnot [String])) -and (($_ -isnot [Int]))) {
                    $errorItem = [System.Management.Automation.ErrorRecord]::new(
                        ([System.ArgumentException]"Invalid Type for Parameter"),
                        'ParameterType.NotJiraIssueLinkType',
                        [System.Management.Automation.ErrorCategory]::InvalidArgument,
                        $_
                    )
                    $errorItem.ErrorDetails = "Wrong object type provided for IssueLinkType. Expected [JiraPS.IssueLinkType], [String] or [Int], but was $($_.GetType().Name)"
                    $PSCmdlet.ThrowTerminatingError($errorItem)
                    <#
                      #ToDo:CustomClass
                      Once we have custom classes, this check can be done with Type declaration
                    #>
                }
                else {
                    return $true
                }
            }
        )]
        [Object]
        $LinkType,

        [PSCredential]
        $Credential
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"

        $server = Get-JiraConfigServer -ErrorAction Stop

        $resourceURi = "$server/rest/api/latest/issueLinkType{0}"
    }

    process {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] ParameterSetName: $($PsCmdlet.ParameterSetName)"
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] PSBoundParameters: $($PSBoundParameters | Out-String)"

        switch ($PSCmdlet.ParameterSetName) {
            '_All' {
                $parameter = @{
                    URI        = $resourceURi -f ""
                    Method     = "GET"
                    Credential = $Credential
                }
                Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
                $result = Invoke-JiraMethod @parameter

                Write-Output (ConvertTo-JiraIssueLinkType -InputObject $result.issueLinkTypes)
            }
            '_Search' {
                # If the link type provided is an int, we can assume it's an ID number.
                # If it's a String, it's probably a name, though, and there isn't an API call to look up a link type by name.
                if ($LinkType -is [Int]) {
                    $parameter = @{
                        URI        = $resourceURi -f "/$LinkType"
                        Method     = "GET"
                        Credential = $Credential
                    }
                    Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
                    $result = Invoke-JiraMethod @parameter

                    Write-Output (ConvertTo-JiraIssueLinkType -InputObject $result)
                }
                else {
                    Write-Output (Get-JiraIssueLinkType -Credential $Credential | Where-Object { $_.Name -like $LinkType })
                }
            }
        }
    }

    end {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}

# .\JiraPS\Public\Get-JiraIssueType.ps1
function Get-JiraIssueType {
    [CmdletBinding( DefaultParameterSetName = '_All' )]
    param(
        [Parameter( Position = 0, Mandatory, ValueFromPipeline, ParameterSetName = '_Search' )]
        [String[]]
        $IssueType,

        [PSCredential]
        $Credential
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"

        $server = Get-JiraConfigServer -ErrorAction Stop

        $resourceURi = "$server/rest/api/latest/issuetype"
    }

    process {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] ParameterSetName: $($PsCmdlet.ParameterSetName)"
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] PSBoundParameters: $($PSBoundParameters | Out-String)"

        switch ($PSCmdlet.ParameterSetName) {
            '_All' {
                $parameter = @{
                    URI        = $resourceURi
                    Method     = "GET"
                    Credential = $Credential
                }
                Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
                $result = Invoke-JiraMethod @parameter

                Write-Output (ConvertTo-JiraIssueType -InputObject $result)
            }
            '_Search' {
                foreach ($_issueType in $IssueType) {
                    Write-Verbose "[$($MyInvocation.MyCommand.Name)] Processing [$_issueType]"
                    Write-Debug "[$($MyInvocation.MyCommand.Name)] Processing `$_issueType [$_issueType]"

                    $allIssueTypes = Get-JiraIssueType -Credential $Credential

                    Write-Output ($allIssueTypes | Where-Object -FilterScript {$_.Id -eq $_issueType})
                    Write-Output ($allIssueTypes | Where-Object -FilterScript {$_.Name -like $_issueType})
                }
            }
        }
    }

    end {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}

# .\JiraPS\Public\Get-JiraIssueWatcher.ps1
function Get-JiraIssueWatcher {
    [CmdletBinding()]
    param(
        [Parameter( Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName )]
        [ValidateNotNullOrEmpty()]
        [ValidateScript(
            {
                if (("JiraPS.Issue" -notin $_.PSObject.TypeNames) -and (($_ -isnot [String]))) {
                    $errorItem = [System.Management.Automation.ErrorRecord]::new(
                        ([System.ArgumentException]"Invalid Type for Parameter"),
                        'ParameterType.NotJiraIssue',
                        [System.Management.Automation.ErrorCategory]::InvalidArgument,
                        $_
                    )
                    $errorItem.ErrorDetails = "Wrong object type provided for Issue. Expected [JiraPS.Issue] or [String], but was $($_.GetType().Name)"
                    $PSCmdlet.ThrowTerminatingError($errorItem)
                    <#
                      #ToDo:CustomClass
                      Once we have custom classes, this check can be done with Type declaration
                    #>
                }
                else {
                    return $true
                }
            }
        )]
        [Alias('Key')]
        [Object]
        $Issue,

        [PSCredential]
        $Credential
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"
    }

    process {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] ParameterSetName: $($PsCmdlet.ParameterSetName)"
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] PSBoundParameters: $($PSBoundParameters | Out-String)"

        # Find the proper object for the Issue
        $issueObj = Resolve-JiraIssueObject -InputObject $Issue -Credential $Credential

        foreach ($issue in $issueObj) {
            $parameter = @{
                URI        = "{0}/watchers" -f $issue.RestURL
                Method     = "GET"
                Credential = $Credential
            }
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
            $result = Invoke-JiraMethod @parameter

            Write-Output $result.watchers
            # TODO: are these users?
        }
    }

    end {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}

# .\JiraPS\Public\Get-JiraPriority.ps1
function Get-JiraPriority {
    [CmdletBinding( DefaultParameterSetName = '_All' )]
    param(
        [Parameter( Position = 0, Mandatory, ValueFromPipeline, ParameterSetName = '_Search' )]
        [Int[]]
        $Id,

        [PSCredential]
        $Credential
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"

        $server = Get-JiraConfigServer -ErrorAction Stop

        $resourceURi = "$server/rest/api/latest/priority{0}"
    }

    process {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] ParameterSetName: $($PsCmdlet.ParameterSetName)"
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] PSBoundParameters: $($PSBoundParameters | Out-String)"

        switch ($PSCmdlet.ParameterSetName) {
            '_All' {
                $parameter = @{
                    URI        = $resourceURi -f ""
                    Method     = "GET"
                    Credential = $Credential
                }
                Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
                $result = Invoke-JiraMethod @parameter

                Write-Output (ConvertTo-JiraPriority -InputObject $result)
            }
            '_Search' {
                foreach ($_id in $Id) {
                    Write-Verbose "[$($MyInvocation.MyCommand.Name)] Processing [$_id]"
                    Write-Debug "[$($MyInvocation.MyCommand.Name)] Processing `$_id [$_id]"

                    $parameter = @{
                        URI        = $resourceURi -f "/$_id"
                        Method     = "GET"
                        Credential = $Credential
                    }
                    Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
                    $result = Invoke-JiraMethod @parameter

                    Write-Output (ConvertTo-JiraPriority -InputObject $result)
                }
            }
        }
    }

    end {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}

# .\JiraPS\Public\Get-JiraProject.ps1
function Get-JiraProject {
    [CmdletBinding( DefaultParameterSetName = '_All' )]
    param(
        [Parameter( Position = 0, Mandatory, ValueFromPipeline, ParameterSetName = '_Search' )]
        [String[]]
        $Project,

        [PSCredential]
        $Credential
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"

        $server = Get-JiraConfigServer -ErrorAction Stop

        $resourceURi = "$server/rest/api/latest/project{0}?expand=description,lead,issueTypes,url,projectKeys"
    }

    process {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] ParameterSetName: $($PsCmdlet.ParameterSetName)"
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] PSBoundParameters: $($PSBoundParameters | Out-String)"

        switch ($PSCmdlet.ParameterSetName) {
            '_All' {
                $parameter = @{
                    URI        = $resourceURi -f ""
                    Method     = "GET"
                    Credential = $Credential
                }
                Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
                $result = Invoke-JiraMethod @parameter

                Write-Output (ConvertTo-JiraProject -InputObject $result)
            }
            '_Search' {
                foreach ($_project in $Project) {
                    Write-Verbose "[$($MyInvocation.MyCommand.Name)] Processing [$_project]"
                    Write-Debug "[$($MyInvocation.MyCommand.Name)] Processing `$_project [$_project]"

                    $parameter = @{
                        URI        = $resourceURi -f "/$($_project)"
                        Method     = "GET"
                        Credential = $Credential
                    }
                    Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
                    $result = Invoke-JiraMethod @parameter

                    Write-Output (ConvertTo-JiraProject -InputObject $result)
                }
            }
        }
    }

    end {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}

# .\JiraPS\Public\Get-JiraRemoteLink.ps1
function Get-JiraRemoteLink {
    [CmdletBinding()]
    param(
        [Parameter( Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName )]
        [ValidateNotNullOrEmpty()]
        [ValidateScript(
            {
                if (("JiraPS.Issue" -notin $_.PSObject.TypeNames) -and (($_ -isnot [String]))) {
                    $errorItem = [System.Management.Automation.ErrorRecord]::new(
                        ([System.ArgumentException]"Invalid Type for Parameter"),
                        'ParameterType.NotJiraIssue',
                        [System.Management.Automation.ErrorCategory]::InvalidArgument,
                        $_
                    )
                    $errorItem.ErrorDetails = "Wrong object type provided for Issue. Expected [JiraPS.Issue] or [String], but was $($_.GetType().Name)"
                    $PSCmdlet.ThrowTerminatingError($errorItem)
                    <#
                      #ToDo:CustomClass
                      Once we have custom classes, this check can be done with Type declaration
                    #>
                }
                else {
                    return $true
                }
            }
        )]
        [Alias("Key")]
        [Object]
        $Issue,

        [Int]
        $LinkId,

        [PSCredential]
        $Credential
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"
    }

    process {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] ParameterSetName: $($PsCmdlet.ParameterSetName)"
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] PSBoundParameters: $($PSBoundParameters | Out-String)"

        foreach ($_issue in $Issue) {
            Write-Verbose "[$($MyInvocation.MyCommand.Name)] Processing [$_issue]"
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Processing `$_issue [$_issue]"

            # Find the proper object for the Issue
            $issueObj = Resolve-JiraIssueObject -InputObject $_issue -Credential $Credential

            $urlAppendix = ""
            if ($LinkId) {
                $urlAppendix = "/$LinkId"
            }

            $parameter = @{
                URI        = "{0}/remotelink{1}" -f $issueObj.RestUrl, $urlAppendix
                Method     = "GET"
                Credential = $Credential
            }
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
            $result = Invoke-JiraMethod @parameter

            Write-Output (ConvertTo-JiraIssueLinkType -InputObject $result)
        }
    }

    end {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}

# .\JiraPS\Public\Get-JiraServerInformation.ps1
function Get-JiraServerInformation {
    [CmdletBinding()]
    param(
        [PSCredential]
        $Credential
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"

        $server = Get-JiraConfigServer -ErrorAction Stop

        $resourceURi = "$server/rest/api/latest/serverInfo"
    }

    process {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] ParameterSetName: $($PsCmdlet.ParameterSetName)"
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] PSBoundParameters: $($PSBoundParameters | Out-String)"

        $parameter = @{
            URI        = $resourceURi
            Method     = "GET"
            Credential = $Credential
        }
        Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
        $result = Invoke-JiraMethod @parameter

        Write-Output (ConvertTo-JiraServerInfo -InputObject $result)
    }

    end {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}

New-Alias -Name "Get-JiraServerInfo" -Value "Get-JiraServerInformation" -ErrorAction SilentlyContinue

# .\JiraPS\Public\Get-JiraSession.ps1
function Get-JiraSession {
    [CmdletBinding()]
    param()

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"
    }

    process {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] ParameterSetName: $($PsCmdlet.ParameterSetName)"
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] PSBoundParameters: $($PSBoundParameters | Out-String)"

        if ($MyInvocation.MyCommand.Module.PrivateData -and $MyInvocation.MyCommand.Module.PrivateData.Session) {
            Write-Verbose "[$($MyInvocation.MyCommand.Name)] Using Session saved in PrivateData"
            Write-Output $MyInvocation.MyCommand.Module.PrivateData.Session
        }
    }

    end {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}

# .\JiraPS\Public\Get-JiraUser.ps1
function Get-JiraUser {
    [CmdletBinding( DefaultParameterSetName = 'ByUserName' )]
    param(
        [Parameter( Position = 0, Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'ByUserName' )]
        [ValidateNotNullOrEmpty()]
        [Alias('User', 'Name')]
        [String[]]
        $UserName,

        [Parameter( Position = 0, Mandatory, ParameterSetName = 'ByInputObject' )]
        [Object[]] $InputObject,

        [Switch]
        $IncludeInactive,

        [PSCredential]
        $Credential
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"

        $server = Get-JiraConfigServer -ErrorAction Stop

        $resourceURi = "$server/rest/api/latest/user/search?username={0}"

        if ($IncludeInactive) {
            $resourceURi += "&includeInactive=true"
        }
    }

    process {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] ParameterSetName: $($PsCmdlet.ParameterSetName)"
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] PSBoundParameters: $($PSBoundParameters | Out-String)"

        if ($InputObject) {
            $UserName = $InputObject.Name
        }

        foreach ($user in $UserName) {
            Write-Verbose "[$($MyInvocation.MyCommand.Name)] Processing [$user]"
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Processing `$user [$user]"

            $parameter = @{
                URI        = $resourceURi -f $user
                Method     = "GET"
                Credential = $Credential
            }
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
            if ($result = Invoke-JiraMethod @parameter) {
                $parameter = @{
                    URI        = "{0}&expand=groups" -f $result.self
                    Method     = "GET"
                    Credential = $Credential
                }
                Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
                $result = Invoke-JiraMethod @parameter

                Write-Output (ConvertTo-JiraUser -InputObject $result)
            }
            else {
                $errorMessage = @{
                    Category         = "ObjectNotFound"
                    CategoryActivity = "Searching for user"
                    Message          = "No results when searching for user $user"
                }
                Write-Error @errorMessage
            }
        }
    }

    end {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}

# .\JiraPS\Public\Get-JiraVersion.ps1
function Get-JiraVersion {
    [CmdletBinding( DefaultParameterSetName = 'byId' )]
    param(
        [Parameter( Mandatory, ParameterSetName = 'byId' )]
        [Int[]]
        $Id,

        [Parameter( Position = 0, Mandatory, ValueFromPipeline, ParameterSetName = 'byInputVersion' )]
        [PSTypeName('JiraPS.Version')]
        $InputVersion,

        [Parameter( Position = 0, Mandatory , ParameterSetName = 'byProject' )]
        [Alias('Key')]
        [String[]]
        $Project,

        [Parameter( Position = 0, Mandatory, ValueFromPipeline, ParameterSetName = 'byInputProject' )]
        [PSTypeName('JiraPS.Project')]
        $InputProject,

        [Parameter( ParameterSetName = 'byProject' )]
        [Parameter( ParameterSetName = 'byInputProject' )]
        [Alias('Versions')]
        [String[]]
        $Name,

        [PSCredential]
        $Credential
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"

        $server = Get-JiraConfigServer -ErrorAction Stop

        $resourceURi = "$server/rest/api/latest/{0}"
    }

    process {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] ParameterSetName: $($PsCmdlet.ParameterSetName)"
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] PSBoundParameters: $($PSBoundParameters | Out-String)"

        $ParameterSetName = ''
        switch ($PsCmdlet.ParameterSetName) {
            'byInputProject' { $Project = $InputProject.Key; $ParameterSetName = 'byProject' }
            'byInputVersion' { $Id = $InputVersion.Id; $ParameterSetName = 'byId' }
            'byProject' { $ParameterSetName = 'byProject' }
            'byId' { $ParameterSetName = 'byId' }
        }

        switch ($ParameterSetName) {
            "byId" {
                foreach ($_id in $ID) {
                    Write-Verbose "[$($MyInvocation.MyCommand.Name)] Processing [$_id]"
                    Write-Debug "[$($MyInvocation.MyCommand.Name)] Processing `$_id [$_id]"

                    $parameter = @{
                        URI        = $resourceURi -f "version/$_id"
                        Method     = "GET"
                        Credential = $Credential
                    }
                    Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
                    $result = Invoke-JiraMethod @parameter

                    Write-Output (ConvertTo-JiraVersion -InputObject $result)
                }
            }
            "byProject" {
                foreach ($_project in $Project) {
                    Write-Verbose "[$($MyInvocation.MyCommand.Name)] Processing [$_project]"
                    Write-Debug "[$($MyInvocation.MyCommand.Name)] Processing `$_project [$_project]"

                    $projectData = Get-JiraProject -Project $_project -Credential $Credential

                    $parameter = @{
                        URI        = $resourceURi -f "project/$($projectData.key)/versions"
                        Method     = "GET"
                        Credential = $Credential
                    }
                    Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
                    $result = Invoke-JiraMethod @parameter

                    if ($Name) {
                        $result = $result | Where-Object {$_.Name -in $Name}
                    }

                    Write-Output (ConvertTo-JiraVersion -InputObject $result)
                }
            }
        }
    }
    end {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}

# .\JiraPS\Public\Invoke-JiraIssueTransition.ps1
function Invoke-JiraIssueTransition {
    [CmdletBinding()]
    param(
        [Parameter( Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName )]
        [ValidateNotNullOrEmpty()]
        [ValidateScript(
            {
                if (("JiraPS.Issue" -notin $_.PSObject.TypeNames) -and (($_ -isnot [String]))) {
                    $errorItem = [System.Management.Automation.ErrorRecord]::new(
                        ([System.ArgumentException]"Invalid Type for Parameter"),
                        'ParameterType.NotJiraIssue',
                        [System.Management.Automation.ErrorCategory]::InvalidArgument,
                        $_
                    )
                    $errorItem.ErrorDetails = "Wrong object type provided for Issue. Expected [JiraPS.Issue] or [String], but was $($_.GetType().Name)"
                    $PSCmdlet.ThrowTerminatingError($errorItem)
                    <#
                      #ToDo:CustomClass
                      Once we have custom classes, this check can be done with Type declaration
                    #>
                }
                else {
                    return $true
                }
            }
        )]
        [Alias('Key')]
        [Object]
        $Issue,

        [Parameter( Mandatory )]
        [Object]
        $Transition,

        [System.Collections.Hashtable]
        $Fields,

        [Object]
        $Assignee,

        [String]
        $Comment,

        [PSCredential]
        $Credential
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"
    }

    process {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] ParameterSetName: $($PsCmdlet.ParameterSetName)"
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] PSBoundParameters: $($PSBoundParameters | Out-String)"

        # Find the proper object for the Issue
        $issueObj = Resolve-JiraIssueObject -InputObject $Issue -Credential $Credential

        if ("JiraPS.Transition" -in $Transition.PSObject.TypeNames) {
            Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] Transition parameter is a JiraPS.Transition object"
            $transitionId = $Transition.Id
        }
        else {
            Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] Attempting to cast Transition parameter [$Transition] as int for transition ID"
            try {
                $transitionId = [Int]"$Transition"
            }
            catch {
                $errorItem = [System.Management.Automation.ErrorRecord]::new(
                    ([System.ArgumentException]"Invalid Type for Parameter"),
                    'ParameterType.NotJiraTransition',
                    [System.Management.Automation.ErrorCategory]::InvalidArgument,
                    $Transition
                )
                $errorItem.ErrorDetails = "Wrong object type provided for Transition. Expected [JiraPS.Transition] or [Int], but was $($Transition.GetType().Name)"
                $PSCmdlet.ThrowTerminatingError($errorItem)
            }
        }

        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] Checking that the issue can perform the given transition"
        if (($issueObj.Transition.Id) -notcontains $transitionId) {
            $errorItem = [System.Management.Automation.ErrorRecord]::new(
                ([System.ArgumentException]"Invalid value for Parameter"),
                'ParameterValue.InvalidTransition',
                [System.Management.Automation.ErrorCategory]::InvalidArgument,
                $Issue
            )
            $errorItem.ErrorDetails = "The specified Jira issue cannot perform transition [$transitionId]. Check the issue's Transition property and provide a transition valid for its current state."
            $PSCmdlet.ThrowTerminatingError($errorItem)
        }

        $requestBody = @{
            'transition' = @{
                'id' = $transitionId
            }
        }

        if ($Assignee) {
            if ($Assignee -eq 'Unassigned') {
                <#
                  #ToDo:Deprecated
                  This behavior should be deprecated
                #>
                Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] 'Unassigned' String passed. Issue will be assigned to no one."
                $assigneeString = ""
                $validAssignee = $true
            }
            else {
                if ($assigneeObj = Get-JiraUser -InputObject $Assignee -Credential $Credential) {
                    Write-Debug "[$($MyInvocation.MyCommand.Name)] User found (name=[$($assigneeObj.Name)],RestUrl=[$($assigneeObj.RestUrl)])"
                    $assigneeString = $assigneeObj.Name
                    $validAssignee = $true
                }
                else {
                    $errorItem = [System.Management.Automation.ErrorRecord]::new(
                        ([System.ArgumentException]"Invalid value for Parameter"),
                        'ParameterValue.InvalidAssignee',
                        [System.Management.Automation.ErrorCategory]::InvalidArgument,
                        $Assignee
                    )
                    $errorItem.ErrorDetails = "Unable to validate Jira user [$Assignee]. Use Get-JiraUser for more details."
                    $PSCmdlet.ThrowTerminatingError($errorItem)
                }
            }
        }

        if ($validAssignee) {
            Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] Updating Assignee"
            $requestBody += @{
                'fields' = @{
                    'assignee' = @{
                        'name' = $assigneeString
                    }
                }
            }
        }

        $requestBody += @{
            'update' = @{}
        }

        if ($Fields) {
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Resolving `$Fields"
            foreach ($key in $Fields.Keys) {
                $name = $key
                $value = $Fields.$key
                Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] Attempting to identify field (name=[$name], value=[$value])"

                if ($field = Get-JiraField -Field $name -Credential $Credential) {
                    # For some reason, this was coming through as a hashtable instead of a String,
                    # which was causing ConvertTo-Json to crash later.
                    # Not sure why, but this forces $id to be a String and not a hashtable.
                    $id = "$($field.ID)"
                    Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] Field [$name] was identified as ID [$id]"
                    $requestBody.update.$id = @( @{
                            'set' = $value
                        })
                }
                else {
                    $errorItem = [System.Management.Automation.ErrorRecord]::new(
                        ([System.ArgumentException]"Invalid value for Parameter"),
                        'ParameterValue.InvalidFields',
                        [System.Management.Automation.ErrorCategory]::InvalidArgument,
                        $Fields
                    )
                    $errorItem.ErrorDetails = "Unable to identify field [$name] from -Fields hashtable. Use Get-JiraField for more information."
                    $PSCmdlet.ThrowTerminatingError($errorItem)
                }
            }
        }

        if ($Comment) {
            Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] Adding comment"
            $requestBody.update.comment += , @{
                'add' = @{
                    'body' = $Comment
                }
            }
        }

        $parameter = @{
            URI        = "{0}/transitions" -f $issueObj.RestURL
            Method     = "POST"
            Body       = ConvertTo-Json -InputObject $requestBody -Depth 4
            Credential = $Credential
        }
        Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
        $result = Invoke-JiraMethod @parameter

        if ($result) {
            # JIRA doesn't typically return results here unless they contain errors, which are handled within Invoke-JiraMethod.
            # If something does come out, let us know.
            Write-Warning "JIRA returned unexpected results, which are provided below."
            Write-Warning "Please report this at $($MyInvocation.MyCommand.Module.PrivateData.PSData.ProjectUri)"
            Write-Output $result
        }
    }

    end {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}

# .\JiraPS\Public\New-JiraGroup.ps1
function New-JiraGroup {
    [CmdletBinding( SupportsShouldProcess )]
    param(
        [Parameter( Mandatory )]
        [Alias('Name')]
        [String[]]
        $GroupName,

        [PSCredential]
        $Credential
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"

        $server = Get-JiraConfigServer -ErrorAction Stop

        $resourceURi = "$server/rest/api/latest/group"
    }

    process {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] ParameterSetName: $($PsCmdlet.ParameterSetName)"
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] PSBoundParameters: $($PSBoundParameters | Out-String)"

        foreach ($_group in $GroupName) {
            Write-Verbose "[$($MyInvocation.MyCommand.Name)] Processing [$_group]"
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Processing `$_group [$_group]"

            $requestBody = @{
                "name" = $_group
            }

            $parameter = @{
                URI        = $resourceURi
                Method     = "POST"
                Body       = ConvertTo-Json -InputObject $requestBody
                Credential = $Credential
            }
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
            if ($PSCmdlet.ShouldProcess($GroupName, "Creating group [$GroupName] to JIRA")) {
                $result = Invoke-JiraMethod @parameter

                Write-Output (ConvertTo-JiraGroup -InputObject $result)
            }
        }
    }

    end {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}

# .\JiraPS\Public\New-JiraIssue.ps1
function New-JiraIssue {
    [CmdletBinding( SupportsShouldProcess )]
    param(
        [Parameter( Mandatory )]
        [String]
        $Project,

        [Parameter( Mandatory )]
        [String]
        $IssueType,

        [Parameter( Mandatory )]
        [String]
        $Summary,

        [Int]
        $Priority,

        [String]
        $Description,

        [AllowNull()]
        [AllowEmptyString()]
        [String]
        $Reporter,

        [String[]]
        $Labels,

        [String]
        $Parent,

        [Alias('FixVersions')]
        [String[]]
        $FixVersion,

        [Hashtable]
        $Fields,

        [PSCredential]
        $Credential
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"

        $server = Get-JiraConfigServer -ErrorAction Stop -Debug:$false

        $createmeta = Get-JiraIssueCreateMetadata -Project $Project -IssueType $IssueType -Credential $Credential -ErrorAction Stop -Debug:$false

        $resourceURi = "$server/rest/api/latest/issue"
    }

    process {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] ParameterSetName: $($PsCmdlet.ParameterSetName)"
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] PSBoundParameters: $($PSBoundParameters | Out-String)"

        $ProjectObj = Get-JiraProject -Project $Project -Credential $Credential -ErrorAction Stop -Debug:$false
        $IssueTypeObj = Get-JiraIssueType -IssueType $IssueType -Credential $Credential -ErrorAction Stop -Debug:$false

        $requestBody = @{
            "project"   = @{"id" = $ProjectObj.Id}
            "issuetype" = @{"id" = [String] $IssueTypeObj.Id}
            "summary"   = $Summary
        }

        if ($Priority) {
            $requestBody["priority"] = @{"id" = [String] $Priority}
        }

        if ($Description) {
            $requestBody["description"] = $Description
        }

        if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey("Reporter")) {
            $requestBody["reporter"] = @{"name" = "$Reporter"}
        }

        if ($Parent) {
            $requestBody["parent"] = @{"key" = $Parent}
        }

        if ($Labels) {
            $requestBody["labels"] = [System.Collections.ArrayList]@()
            foreach ($item in $Labels) {
                $null = $requestBody["labels"].Add($item)
            }
        }

        if ($FixVersion) {
            $requestBody['fixVersions'] = [System.Collections.ArrayList]@()
            foreach ($item in $FixVersion) {
                $null = $requestBody["fixVersions"].Add( @{ name = "$item" } )
            }
        }

        Write-Debug "[$($MyInvocation.MyCommand.Name)] Resolving `$Fields"
        foreach ($_key in $Fields.Keys) {
            $name = $_key
            $value = $Fields.$_key

            if ($field = Get-JiraField -Field $name -Credential $Credential -Debug:$false) {
                # For some reason, this was coming through as a hashtable instead of a String,
                # which was causing ConvertTo-Json to crash later.
                # Not sure why, but this forces $id to be a String and not a hashtable.
                $id = $field.Id
                $requestBody["$id"] = $value
            }
            else {
                $errorItem = [System.Management.Automation.ErrorRecord]::new(
                    ([System.ArgumentException]"Invalid value for Parameter"),
                    'ParameterValue.InvalidFields',
                    [System.Management.Automation.ErrorCategory]::InvalidArgument,
                    $Fields
                )
                $errorItem.ErrorDetails = "Unable to identify field [$name] from -Fields hashtable. Use Get-JiraField for more information."
                $PSCmdlet.ThrowTerminatingError($errorItem)
            }
        }

        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Validating fields with metadata"
        foreach ($c in $createmeta) {
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Checking metadata for `$c [$c]"
            if ($c.Required) {
                if ($requestBody.ContainsKey($c.Id)) {
                    Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] Required field (id=[$($c.Id)], name=[$($c.Name)]) was provided (value=[$($requestBody.$($c.Id))])"
                }
                else {
                    $errorItem = [System.Management.Automation.ErrorRecord]::new(
                        ([System.ArgumentException]"Invalid or missing value Parameter"),
                        'ParameterValue.CreateMetaFailure',
                        [System.Management.Automation.ErrorCategory]::InvalidArgument,
                        $Fields
                    )
                    $errorItem.ErrorDetails = "Jira's metadata for project [$Project] and issue type [$IssueType] specifies that a field is required that was not provided (name=[$($c.Name)], id=[$($c.Id)]). Use Get-JiraIssueCreateMetadata for more information."
                    $PSCmdlet.ThrowTerminatingError($errorItem)
                }
            }
            else {
                Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] Non-required field (id=[$($c.Id)], name=[$($c.Name)])"
            }
        }

        $hashtable = @{
            'fields' = ([PSCustomObject]$requestBody)
        }

        $parameter = @{
            URI        = $resourceURi
            Method     = "POST"
            Body       = (ConvertTo-Json -InputObject ([PSCustomObject]$hashtable) -Depth 7)
            Credential = $Credential
        }
        Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
        if ($PSCmdlet.ShouldProcess($Summary, "Creating new Issue on JIRA")) {
            $result = Invoke-JiraMethod @parameter

            # REST result will look something like this:
            # {"id":"12345","key":"IT-3676","self":"http://jiraserver.example.com/rest/api/latest/issue/12345"}
            # This will fetch the created issue to return it with all it'a properties
            Write-Output (Get-JiraIssue -Key $result.Key -Credential $Credential)
        }
    }

    end {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}

# .\JiraPS\Public\New-JiraSession.ps1
function New-JiraSession {
    [CmdletBinding()]
    [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseShouldProcessForStateChangingFunctions', '')]
    param(
        [Parameter( Mandatory )]
        [PSCredential]
        $Credential,

        [Hashtable]
        $Headers = @{}
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"

        $server = Get-JiraConfigServer -ErrorAction Stop

        $resourceURi = "$server/rest/api/2/mypermissions"

        # load DefaultParameters for Invoke-WebRequest
        # as the global PSDefaultParameterValues is not used
        $PSDefaultParameterValues = $global:PSDefaultParameterValues

        $SecureCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(
                $('{0}:{1}' -f $Credential.UserName, $Credential.GetNetworkCredential().Password)
            ))
        $Headers.Add('Authorization', "Basic $SecureCreds")
    }

    process {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] ParameterSetName: $($PsCmdlet.ParameterSetName)"
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] PSBoundParameters: $($PSBoundParameters | Out-String)"

        $parameters = @{
            Uri             = $resourceURi
            Method          = "GET"
            ContentType     = 'application/json; charset=utf-8'
            Headers         = $Headers
            UseBasicParsing = $true
            SessionVariable = "newSessionVar"
            ErrorAction     = 'SilentlyContinue'
        }

        if ($Headers.ContainsKey("Content-Type")) {
            $parameters["ContentType"] = $Headers["Content-Type"]
            $Headers.Remove("Content-Type")
            $parameters["Headers"] = $Headers
        }

        try {
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
            $webResponse = Invoke-WebRequest @parameters

            $result = ConvertTo-JiraSession -Session $newSessionVar -Username $Credential.UserName

            if ($MyInvocation.MyCommand.Module.PrivateData) {
                Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] Adding session result to existing module PrivateData"
                $MyInvocation.MyCommand.Module.PrivateData.Session = $result
            }
            else {
                Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] Creating module PrivateData"
                $MyInvocation.MyCommand.Module.PrivateData = @{
                    'Session' = $result
                }
            }

            Write-Output $result
        }
        catch {
            $webResponse = $_.Exception.Response
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Encountered an exception from the Jira server: `$err"

            # Test response Headers if Jira requires a CAPTCHA
            Test-Captcha -InputObject $webResponse

            Write-Verbose "JIRA returned HTTP error $($webResponse.StatusCode.value__) - $($webResponse.StatusCode)"

            # Retrieve body of HTTP response - this contains more useful information about exactly why the error
            # occurred
            $readStream = New-Object -TypeName System.IO.StreamReader -ArgumentList ($webResponse.GetResponseStream())
            $body = $readStream.ReadToEnd()
            $readStream.Close()
            Write-Debug "Retrieved body of HTTP response for more information about the error (`$body)"

            # Clear the body in case it is not a JSON (but rather html)
            if ($body -match "^[\s\t]*\<html\>") { $body = "" }

            $result = ConvertFrom-Json2 -InputObject $body
            Write-Debug "Converted body from JSON into PSCustomObject (`$result)"
        }
    }

    end {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}

# .\JiraPS\Public\New-JiraUser.ps1
function New-JiraUser {
    [CmdletBinding( SupportsShouldProcess )]
    param(
        [Parameter( Mandatory )]
        [String]
        $UserName,

        [Parameter( Mandatory )]
        [Alias('Email')]
        [String]
        $EmailAddress,

        [String]
        $DisplayName,

        [Boolean]
        $Notify = $true,

        [PSCredential]
        $Credential
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"

        $server = Get-JiraConfigServer -ErrorAction Stop

        $resourceURi = "$server/rest/api/latest/user"
    }

    process {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] ParameterSetName: $($PsCmdlet.ParameterSetName)"
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] PSBoundParameters: $($PSBoundParameters | Out-String)"

        $requestBody = @{
            "name"         = $UserName
            "emailAddress" = $EmailAddress
            "notify"       = $Notify
        }

        if ($DisplayName) {
            $requestBody.displayName = $DisplayName
        }
        else {
            Write-DebugMessage "[New-JiraUser] DisplayName was not specified; defaulting to UserName parameter [$UserName]"
            $requestBody.displayName = $UserName
        }

        $parameter = @{
            URI        = $resourceURi
            Method     = "POST"
            Body       = ConvertTo-Json -InputObject $requestBody
            Credential = $Credential
        }
        Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
        if ($PSCmdlet.ShouldProcess($UserName, "Creating new User on JIRA")) {
            $result = Invoke-JiraMethod @parameter

            Write-Output (ConvertTo-JiraUser -InputObject $result)
        }
    }

    end {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}

# .\JiraPS\Public\New-JiraVersion.ps1
function New-JiraVersion {
    [CmdletBinding( SupportsShouldProcess, DefaultParameterSetName = 'byObject' )]
    param(
        [Parameter( Position = 0, Mandatory, ValueFromPipeline, ParameterSetName = 'byObject' )]
        [ValidateNotNullOrEmpty()]
        [ValidateScript(
            {
                if (("JiraPS.Version" -notin $_.PSObject.TypeNames) -and (($_ -isnot [String]))) {
                    $errorItem = [System.Management.Automation.ErrorRecord]::new(
                        ([System.ArgumentException]"Invalid Type for Parameter"),
                        'ParameterType.NotJiraVersion',
                        [System.Management.Automation.ErrorCategory]::InvalidArgument,
                        $_
                    )
                    $errorItem.ErrorDetails = "Wrong object type provided for Version. Expected [JiraPS.Version] or [String], but was $($_.GetType().Name)"
                    $PSCmdlet.ThrowTerminatingError($errorItem)
                    <#
                      #ToDo:CustomClass
                      Once we have custom classes, this check can be done with Type declaration
                    #>
                }
                else {
                    return $true
                }
            }
        )]
        [Object]
        $InputObject,

        [Parameter( Position = 0, Mandatory, ParameterSetName = 'byParameters' )]
        [String]
        $Name,

        [Parameter( Position = 1, Mandatory, ParameterSetName = 'byParameters' )]
        [ValidateNotNullOrEmpty()]
        [ValidateScript(
            {
                $Input = $_

                switch ($true) {
                    {"JiraPS.Project" -in $Input.PSObject.TypeNames} { return $true }
                    {$Input -is [String]} { return $true}
                    Default {
                        $errorItem = [System.Management.Automation.ErrorRecord]::new(
                            ([System.ArgumentException]"Invalid Type for Parameter"),
                            'ParameterType.NotJiraProject',
                            [System.Management.Automation.ErrorCategory]::InvalidArgument,
                            $Input
                        )
                        $errorItem.ErrorDetails = "Wrong object type provided for Project. Expected [JiraPS.Project] or [String], but was $($Input.GetType().Name)"
                        $PSCmdlet.ThrowTerminatingError($errorItem)
                        <#
                          #ToDo:CustomClass
                          Once we have custom classes, this check can be done with Type declaration
                        #>
                    }
                }
            }
        )]
        [Object]
        $Project,

        [Parameter( ParameterSetName = 'byParameters' )]
        [String]
        $Description,

        [Parameter( ParameterSetName = 'byParameters' )]
        [Bool]
        $Archived,

        [Parameter( ParameterSetName = 'byParameters' )]
        [Bool]
        $Released,

        [Parameter( ParameterSetName = 'byParameters' )]
        [DateTime]
        $ReleaseDate,

        [Parameter( ParameterSetName = 'byParameters' )]
        [DateTime]
        $StartDate,

        [PSCredential]
        $Credential
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"

        $server = Get-JiraConfigServer -ErrorAction Stop

        $resourceURi = "$server/rest/api/latest/version"
    }

    process {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] ParameterSetName: $($PsCmdlet.ParameterSetName)"
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] PSBoundParameters: $($PSBoundParameters | Out-String)"

        $requestBody = @{}
        Switch ($PSCmdlet.ParameterSetName) {
            'byObject' {
                $requestBody["name"] = $InputObject.Name
                $requestBody["description"] = $InputObject.Description
                $requestBody["archived"] = [bool]($InputObject.Archived)
                $requestBody["released"] = [bool]($InputObject.Released)
                $requestBody["releaseDate"] = $InputObject.ReleaseDate.ToString('yyyy-MM-dd')
                $requestBody["startDate"] = $InputObject.StartDate.ToString('yyyy-MM-dd')
                if ($InputObject.Project.Key) {
                    $requestBody["project"] = $InputObject.Project.Key
                }
                elseif ($InputObject.Project.Id) {
                    $requestBody["projectId"] = $InputObject.Project.Id
                }
            }
            'byParameters' {
                $requestBody["name"] = $Name
                if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey("Description")) {
                    $requestBody["description"] = $Description
                }
                if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey("Archived")) {
                    $requestBody["archived"] = $Archived
                }
                if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey("Released")) {
                    $requestBody["released"] = $Released
                }
                if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey("ReleaseDate")) {
                    $requestBody["releaseDate"] = Get-Date $ReleaseDate -Format 'yyyy-MM-dd'
                }
                if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey("StartDate")) {
                    $requestBody["startDate"] = Get-Date $StartDate -Format 'yyyy-MM-dd'
                }

                if ("JiraPS.Project" -in $Project.PSObject.TypeNames) {
                    if ($Project.Id) {
                        $requestBody["projectId"] = $Project.Id
                    }
                    elseif ($Project.Key) {
                        $requestBody["project"] = $Project.Key
                    }
                }
                else {
                    $requestBody["projectId"] = (Get-JiraProject $Project -Credential $Credential).Id
                }
            }
        }

        $parameter = @{
            URI        = $resourceURi
            Method     = "POST"
            Body       = ConvertTo-Json -InputObject $requestBody
            Credential = $Credential
        }
        Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
        if ($PSCmdlet.ShouldProcess($Name, "Creating new Version on JIRA")) {
            $result = Invoke-JiraMethod @parameter

            Write-Output (ConvertTo-JiraVersion -InputObject $result)
        }
    }

    end {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}

# .\JiraPS\Public\Remove-JiraGroup.ps1
function Remove-JiraGroup {
    [CmdletBinding( SupportsShouldProcess, ConfirmImpact = 'High' )]
    param(
        [Parameter( Mandatory, ValueFromPipeline )]
        [ValidateNotNullOrEmpty()]
        [ValidateScript(
            {
                if (("JiraPS.Group" -notin $_.PSObject.TypeNames) -and (($_ -isnot [String]))) {
                    $errorItem = [System.Management.Automation.ErrorRecord]::new(
                        ([System.ArgumentException]"Invalid Type for Parameter"),
                        'ParameterType.NotJiraGroup',
                        [System.Management.Automation.ErrorCategory]::InvalidArgument,
                        $_
                    )
                    $errorItem.ErrorDetails = "Wrong object type provided for Group. Expected [JiraPS.Group] or [String], but was $($_.GetType().Name)"
                    $PSCmdlet.ThrowTerminatingError($errorItem)
                    <#
                      #ToDo:CustomClass
                      Once we have custom classes, this check can be done with Type declaration
                    #>
                }
                else {
                    return $true
                }
            }
        )]
        [Alias('GroupName')]
        [Object[]]
        $Group,

        [PSCredential]
        $Credential,

        [Switch]
        $Force
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"

        $server = Get-JiraConfigServer -ErrorAction Stop

        $resourceURi = "$server/rest/api/latest/group?groupname={0}"

        if ($Force) {
            Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] -Force was passed. Backing up current ConfirmPreference [$ConfirmPreference] and setting to None"
            $oldConfirmPreference = $ConfirmPreference
            $ConfirmPreference = 'None'
        }
    }

    process {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] ParameterSetName: $($PsCmdlet.ParameterSetName)"
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] PSBoundParameters: $($PSBoundParameters | Out-String)"

        foreach ($_group in $Group) {
            Write-Verbose "[$($MyInvocation.MyCommand.Name)] Processing [$_group]"
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Processing `$_group [$_group]"

            $groupObj = Get-JiraGroup -GroupName $_group -Credential $Credential -ErrorAction Stop

            $parameter = @{
                URI        = $resourceURi -f $groupObj.Name
                Method     = "DELETE"
                Credential = $Credential
            }
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
            if ($PSCmdlet.ShouldProcess($groupObj.Name, "Remove group")) {
                Invoke-JiraMethod @parameter
            }
        }
    }

    end {
        if ($Force) {
            Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] Restoring ConfirmPreference to [$oldConfirmPreference]"
            $ConfirmPreference = $oldConfirmPreference
        }

        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}

# .\JiraPS\Public\Remove-JiraGroupMember.ps1
function Remove-JiraGroupMember {
    [CmdletBinding( SupportsShouldProcess, ConfirmImpact = 'High' )]
    param(
        [Parameter( Mandatory, ValueFromPipeline )]
        [ValidateNotNullOrEmpty()]
        [ValidateScript(
            {
                if (("JiraPS.Group" -notin $_.PSObject.TypeNames) -and (($_ -isnot [String]))) {
                    $errorItem = [System.Management.Automation.ErrorRecord]::new(
                        ([System.ArgumentException]"Invalid Type for Parameter"),
                        'ParameterType.NotJiraGroup',
                        [System.Management.Automation.ErrorCategory]::InvalidArgument,
                        $_
                    )
                    $errorItem.ErrorDetails = "Wrong object type provided for Group. Expected [JiraPS.Group] or [String], but was $($_.GetType().Name)"
                    $PSCmdlet.ThrowTerminatingError($errorItem)
                    <#
                      #ToDo:CustomClass
                      Once we have custom classes, this check can be done with Type declaration
                    #>
                }
                else {
                    return $true
                }
            }
        )]
        [Alias('GroupName')]
        [Object[]]
        $Group,

        [Parameter( Mandatory )]
        [ValidateNotNullOrEmpty()]
        [ValidateScript(
            {
                if (("JiraPS.User" -notin $_.PSObject.TypeNames) -and (($_ -isnot [String]))) {
                    $errorItem = [System.Management.Automation.ErrorRecord]::new(
                        ([System.ArgumentException]"Invalid Type for Parameter"),
                        'ParameterType.UotJirauser',
                        [System.Management.Automation.ErrorCategory]::InvalidArgument,
                        $_
                    )
                    $errorItem.ErrorDetails = "Wrong object type provided for User. Expected [JiraPS.User] or [String], but was $($_.GetType().Name)"
                    $PSCmdlet.ThrowTerminatingError($errorItem)
                    <#
                      #ToDo:CustomClass
                      Once we have custom classes, this check can be done with Type declaration
                    #>
                }
                else {
                    return $true
                }
            }
        )]
        [Alias('UserName')]
        [Object[]]
        $User,

        [PSCredential]
        $Credential,

        [Switch]
        $PassThru,

        [Switch]
        $Force
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"

        $server = Get-JiraConfigServer -ErrorAction Stop

        $resourceURi = "$server/rest/api/latest/group/user?groupname={0}&username={1}"

        if ($Force) {
            Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] -Force was passed. Backing up current ConfirmPreference [$ConfirmPreference] and setting to None"
            $oldConfirmPreference = $ConfirmPreference
            $ConfirmPreference = 'None'
        }
    }

    process {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] ParameterSetName: $($PsCmdlet.ParameterSetName)"
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] PSBoundParameters: $($PSBoundParameters | Out-String)"

        foreach ($_group in $Group) {
            Write-Verbose "[$($MyInvocation.MyCommand.Name)] Processing [$_group]"
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Processing `$_group [$_group]"

            $groupObj = Get-JiraGroup -GroupName $_group -Credential $Credential -ErrorAction Stop
            # $groupMembers = (Get-JiraGroupMember -Group $_group -Credential $Credential -ErrorAction Stop).Name

            foreach ($_user in $User) {
                Write-Verbose "[$($MyInvocation.MyCommand.Name)] Processing [$_user]"
                Write-Debug "[$($MyInvocation.MyCommand.Name)] Processing `$_user [$_user]"

                $userObj = Get-JiraUser -InputObject $_user -Credential $Credential -ErrorAction Stop

                # if ($groupMembers -contains $userObj.Name) {
                # TODO: test what jira says
                $parameter = @{
                    URI        = $resourceURi -f $groupObj.Name, $userObj.Name
                    Method     = "DELETE"
                    Credential = $Credential
                }
                Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
                if ($PSCmdlet.ShouldProcess($groupObj.Name, "Remove $($userObj.Name) from group")) {
                    Invoke-JiraMethod @parameter
                }
                # }
            }

            if ($PassThru) {
                Write-Output (Get-JiraGroup -InputObject $g -Credential $Credential)
            }
        }
    }

    end {
        if ($Force) {
            Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] Restoring ConfirmPreference to [$oldConfirmPreference]"
            $ConfirmPreference = $oldConfirmPreference
        }

        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}

# .\JiraPS\Public\Remove-JiraIssueAttachment.ps1
function Remove-JiraIssueAttachment {
    [CmdletBinding( ConfirmImpact = 'High', SupportsShouldProcess, DefaultParameterSetName = 'byId' )]
    param(
        [Parameter( Position = 0, Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'byId' )]
        [ValidateNotNullOrEmpty()]
        [Alias('Id')]
        [Int[]]
        $AttachmentId,

        [Parameter( Position = 0, Mandatory, ParameterSetName = 'byIssue' )]
        [ValidateNotNullOrEmpty()]
        [ValidateScript(
            {
                if (("JiraPS.Issue" -notin $_.PSObject.TypeNames) -and (($_ -isnot [String]))) {
                    $errorItem = [System.Management.Automation.ErrorRecord]::new(
                        ([System.ArgumentException]"Invalid Type for Parameter"),
                        'ParameterType.NotJiraIssue',
                        [System.Management.Automation.ErrorCategory]::InvalidArgument,
                        $_
                    )
                    $errorItem.ErrorDetails = "Wrong object type provided for Issue. Expected [JiraPS.Issue] or [String], but was $($_.GetType().Name)"
                    $PSCmdlet.ThrowTerminatingError($errorItem)
                    <#
                      #ToDo:CustomClass
                      Once we have custom classes, this check can be done with Type declaration
                    #>
                }
                else {
                    return $true
                }
            }
        )]
        [Alias('Key')]
        [Object]
        $Issue,

        [Parameter( ParameterSetName = 'byIssue' )]
        [String[]]
        $FileName,

        [PSCredential]
        $Credential,

        [Switch]
        $Force
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"

        $server = Get-JiraConfigServer -ErrorAction Stop

        $resourceURi = "$server/rest/api/latest/attachment/{0}"

        if ($Force) {
            Write-DebugMessage "[Remove-JiraGroupMember] -Force was passed. Backing up current ConfirmPreference [$ConfirmPreference] and setting to None"
            $oldConfirmPreference = $ConfirmPreference
            $ConfirmPreference = 'None'
        }
    }

    process {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] ParameterSetName: $($PsCmdlet.ParameterSetName)"
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] PSBoundParameters: $($PSBoundParameters | Out-String)"

        switch ($PsCmdlet.ParameterSetName) {
            "byId" {
                foreach ($_id in $AttachmentId) {
                    Write-Verbose "[$($MyInvocation.MyCommand.Name)] Processing [$_id]"
                    Write-Debug "[$($MyInvocation.MyCommand.Name)] Processing `$_id [$_id]"

                    $parameter = @{
                        URI        = $resourceURi -f $_id
                        Method     = "DELETE"
                        Credential = $Credential
                    }
                    Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
                    if ($PSCmdlet.ShouldProcess($thisUrl, "Removing an attachment")) {
                        Invoke-JiraMethod @parameter
                    }
                }
            }
            "byIssue" {
                Write-Verbose "[$($MyInvocation.MyCommand.Name)] Processing [$Issue]"
                Write-Debug "[$($MyInvocation.MyCommand.Name)] Processing `$Issue [$Issue]"

                if (@($Issue).Count -ne 1) {
                    $errorItem = [System.Management.Automation.ErrorRecord]::new(
                        ([System.ArgumentException]"invalid Issue provided"),
                        'ParameterValue.JiraIssue',
                        [System.Management.Automation.ErrorCategory]::InvalidArgument,
                        $_
                    )
                    $errorItem.ErrorDetails = "Only one Issue can be provided at a time."
                    $PSCmdlet.ThrowTerminatingError($errorItem)
                }

                # Find the proper object for the Issue
                $issueObj = Resolve-JiraIssueObject -InputObject $Issue -Credential $Credential
                $attachments = Get-JiraIssueAttachment -Issue $IssueObj -Credential $Credential -ErrorAction Stop

                if ($FileName) {
                    $_attachments = @()
                    foreach ($file in $FileName) {
                        $_attachments += $attachments | Where-Object {$_.FileName -like $file}
                    }
                    $attachments = $_attachments
                }

                foreach ($attachment in $attachments) {
                    Write-Verbose "[$($MyInvocation.MyCommand.Name)] Processing [$attachment]"
                    Write-Debug "[$($MyInvocation.MyCommand.Name)] Processing `$attachment [$attachment]"

                    $parameter = @{
                        URI        = $resourceURi -f $attachment.Id
                        Method     = "DELETE"
                        Credential = $Credential
                    }
                    Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
                    if ($PSCmdlet.ShouldProcess($Issue.Key, "Removing attachment '$($attachment.FileName)'")) {
                        Invoke-JiraMethod @parameter
                    }
                }
            }
        }
    }

    end {
        if ($Force) {
            Write-DebugMessage "[Remove-JiraGroupMember] Restoring ConfirmPreference to [$oldConfirmPreference]"
            $ConfirmPreference = $oldConfirmPreference
        }

        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}

# .\JiraPS\Public\Remove-JiraIssueLink.ps1
function Remove-JiraIssueLink {
    [CmdletBinding( SupportsShouldProcess, ConfirmImpact = 'Medium' )]
    param(
        [Parameter( Mandatory, ValueFromPipeline )]
        [ValidateNotNullOrEmpty()]
        [ValidateScript(
            {
                $Input = $_
                $objectProperties = $Input | Get-Member -MemberType *Property
                switch ($true) {
                    {("JiraPS.Issue" -in $Input.PSObject.TypeNames) -and ("issueLinks" -in $objectProperties.Name)} { return $true }
                    {("JiraPS.IssueLink" -in $Input.PSObject.TypeNames) -and ("Id" -in $objectProperties.Name)} { return $true }
                    default {
                        $errorItem = [System.Management.Automation.ErrorRecord]::new(
                            ([System.ArgumentException]"Invalid Type for Parameter"),
                            'ParameterType.NotJiraIssue',
                            [System.Management.Automation.ErrorCategory]::InvalidArgument,
                            $Input
                        )
                        $errorItem.ErrorDetails = "Wrong object type provided for Issue. Expected [JiraPS.Issue], [JiraPS.IssueLink] or [String], but was $($Input.GetType().Name)"
                        $PSCmdlet.ThrowTerminatingError($errorItem)
                        <#
                          #ToDo:CustomClass
                          Once we have custom classes, this check can be done with Type declaration
                        #>
                    }
                }
            }
        )]
        [Object[]]
        $IssueLink,

        [PSCredential]
        $Credential
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"

        $server = Get-JiraConfigServer -ErrorAction Stop

        $resourceURi = "$server/rest/api/latest/issueLink/{0}"
    }

    process {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] ParameterSetName: $($PsCmdlet.ParameterSetName)"
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] PSBoundParameters: $($PSBoundParameters | Out-String)"

        # As we are not able to use proper type casting in the parameters, this is a workaround
        # to extract the data from a JiraPS.Issue object
        <#
          #ToDo:CustomClass
          Once we have custom classes, this will no longer be necessary
        #>
        if ($IssueLink.issueLinks) {
            $IssueLink = $IssueLink.issueLinks
        }

        foreach ($link in $IssueLink) {
            Write-Verbose "[$($MyInvocation.MyCommand.Name)] Processing [$link]"
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Processing `$link [$link]"

            $parameter = @{
                URI        = $resourceURi -f $link.id
                Method     = "DELETE"
                Credential = $Credential
            }
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
            if ($PSCmdlet.ShouldProcess($link.id, "Remove IssueLink")) {
                Invoke-JiraMethod @parameter
            }
        }
    }

    end {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}

# .\JiraPS\Public\Remove-JiraIssueWatcher.ps1
function Remove-JiraIssueWatcher {
    [CmdletBinding( SupportsShouldProcess )]
    param(
        [Parameter( Mandatory )]
        [string[]]
        $Watcher,

        [Parameter( Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName )]
        [ValidateNotNullOrEmpty()]
        [ValidateScript(
            {
                if (("JiraPS.Issue" -notin $_.PSObject.TypeNames) -and (($_ -isnot [String]))) {
                    $errorItem = [System.Management.Automation.ErrorRecord]::new(
                        ([System.ArgumentException]"Invalid Type for Parameter"),
                        'ParameterType.NotJiraIssue',
                        [System.Management.Automation.ErrorCategory]::InvalidArgument,
                        $_
                    )
                    $errorItem.ErrorDetails = "Wrong object type provided for Issue. Expected [JiraPS.Issue] or [String], but was $($_.GetType().Name)"
                    $PSCmdlet.ThrowTerminatingError($errorItem)
                    <#
                      #ToDo:CustomClass
                      Once we have custom classes, this check can be done with Type declaration
                    #>
                }
                else {
                    return $true
                }
            }
        )]
        [Alias('Key')]
        [Object]
        $Issue,

        [PSCredential]
        $Credential
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"
    }

    process {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] ParameterSetName: $($PsCmdlet.ParameterSetName)"
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] PSBoundParameters: $($PSBoundParameters | Out-String)"

        # Find the proper object for the Issue
        $issueObj = Resolve-JiraIssueObject -InputObject $Issue -Credential $Credential

        foreach ($username in $Watcher) {
            Write-Verbose "[$($MyInvocation.MyCommand.Name)] Processing [$username]"
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Processing `$username [$username]"

            $parameter = @{
                URI        = "{0}/watchers?username={1}" -f $issueObj.RestURL, $username
                Method     = "DELETE"
                Credential = $Credential
            }
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
            if ($PSCmdlet.ShouldProcess($IssueObj.Key, "Removing watcher '$($username)'")) {
                Invoke-JiraMethod @parameter
            }
        }
    }

    end {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}

# .\JiraPS\Public\Remove-JiraRemoteLink.ps1
function Remove-JiraRemoteLink {
    [CmdletBinding( ConfirmImpact = 'High', SupportsShouldProcess )]
    param(
        [Parameter( Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName )]
        [ValidateNotNullOrEmpty()]
        [ValidateScript(
            {
                if (("JiraPS.Issue" -notin $_.PSObject.TypeNames) -and (($_ -isnot [String]))) {
                    $errorItem = [System.Management.Automation.ErrorRecord]::new(
                        ([System.ArgumentException]"Invalid Type for Parameter"),
                        'ParameterType.NotJiraIssue',
                        [System.Management.Automation.ErrorCategory]::InvalidArgument,
                        $_
                    )
                    $errorItem.ErrorDetails = "Wrong object type provided for Issue. Expected [JiraPS.Issue] or [String], but was $($_.GetType().Name)"
                    $PSCmdlet.ThrowTerminatingError($errorItem)
                    <#
                      #ToDo:CustomClass
                      Once we have custom classes, this check can be done with Type declaration
                    #>
                }
                else {
                    return $true
                }
            }
        )]
        [Alias("Key")]
        [Object[]]
        $Issue,

        [Parameter( Mandatory )]
        [Int[]]
        $LinkId,

        [PSCredential]
        $Credential,

        [Switch]
        $Force
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"

        $server = Get-JiraConfigServer -ErrorAction Stop

        $resourceURi = "$server/rest/api/latest/issue/{0}/remotelink/{1}"

        if ($Force) {
            Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] -Force was passed. Backing up current ConfirmPreference [$ConfirmPreference] and setting to None"
            $oldConfirmPreference = $ConfirmPreference
            $ConfirmPreference = 'None'
        }
    }

    process {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] ParameterSetName: $($PsCmdlet.ParameterSetName)"
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] PSBoundParameters: $($PSBoundParameters | Out-String)"

        foreach ($_issue in $Issue) {
            Write-Verbose "[$($MyInvocation.MyCommand.Name)] Processing [$Issue]"
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Processing `$Issue [$Issue]"

            # Find the proper object for the Issue
            $issueObj = Resolve-JiraIssueObject -InputObject $_issue -Credential $Credential

            foreach ($_link in $LinkId) {
                Write-Verbose "[$($MyInvocation.MyCommand.Name)] Processing [$_link]"
                Write-Debug "[$($MyInvocation.MyCommand.Name)] Processing `$_link [$_link]"

                $parameter = @{
                    URI        = $resourceURi -f $issueObj.Key, $_link
                    Method     = "DELETE"
                    Credential = $Credential
                }
                Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
                if ($PSCmdlet.ShouldProcess($issueObj.Key, "Remove RemoteLink '$_link'")) {
                    Invoke-JiraMethod @parameter
                }
            }
        }
    }

    end {
        if ($Force) {
            Write-DebugMessage "[Remove-JiraGroupMember] Restoring ConfirmPreference to [$oldConfirmPreference]"
            $ConfirmPreference = $oldConfirmPreference
        }

        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}

# .\JiraPS\Public\Remove-JiraSession.ps1
function Remove-JiraSession {
    [CmdletBinding()]
    [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseShouldProcessForStateChangingFunctions', '')]
    param(
        [Parameter( ValueFromPipeline )]
        [Object]
        $Session
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"
    }

    process {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] ParameterSetName: $($PsCmdlet.ParameterSetName)"
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] PSBoundParameters: $($PSBoundParameters | Out-String)"

        if ($Session = Get-JiraSession) {
            $MyInvocation.MyCommand.Module.PrivateData.Session = $null
        }
    }

    end {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}

# .\JiraPS\Public\Remove-JiraUser.ps1
function Remove-JiraUser {
    [CmdletBinding( ConfirmImpact = 'High', SupportsShouldProcess )]
    param(
        [Parameter( Mandatory, ValueFromPipeline )]
        [ValidateNotNullOrEmpty()]
        [ValidateScript(
            {
                if (("JiraPS.User" -notin $_.PSObject.TypeNames) -and (($_ -isnot [String]))) {
                    $errorItem = [System.Management.Automation.ErrorRecord]::new(
                        ([System.ArgumentException]"Invalid Type for Parameter"),
                        'ParameterType.NotJiraUser',
                        [System.Management.Automation.ErrorCategory]::InvalidArgument,
                        $_
                    )
                    $errorItem.ErrorDetails = "Wrong object type provided for User. Expected [JiraPS.User] or [String], but was $($_.GetType().Name)"
                    $PSCmdlet.ThrowTerminatingError($errorItem)
                    <#
                      #ToDo:CustomClass
                      Once we have custom classes, this check can be done with Type declaration
                    #>
                }
                else {
                    return $true
                }
            }
        )]
        [Alias('UserName')]
        [Object[]]
        $User,

        [PSCredential]
        $Credential,

        [Switch]
        $Force
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"

        $server = Get-JiraConfigServer -ErrorAction Stop

        $resourceURi = "$server/rest/api/latest/user?username={0}"

        if ($Force) {
            Write-DebugMessage "[Remove-JiraGroup] -Force was passed. Backing up current ConfirmPreference [$ConfirmPreference] and setting to None"
            $oldConfirmPreference = $ConfirmPreference
            $ConfirmPreference = 'None'
        }
    }

    process {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] ParameterSetName: $($PsCmdlet.ParameterSetName)"
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] PSBoundParameters: $($PSBoundParameters | Out-String)"

        foreach ($_user in $User) {
            Write-Verbose "[$($MyInvocation.MyCommand.Name)] Processing [$_user]"
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Processing `$_user [$_user]"

            $userObj = Get-JiraUser -InputObject $_user -Credential $Credential -ErrorAction Stop

            $parameter = @{
                URI        = $resourceURi -f $userObj.Name
                Method     = "DELETE"
                Credential = $Credential
            }
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
            if ($PSCmdlet.ShouldProcess($userObj.Name, 'Remove user')) {
                Invoke-JiraMethod @parameter
            }
        }
    }

    end {
        if ($Force) {
            Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] Restoring ConfirmPreference to [$oldConfirmPreference]"
            $ConfirmPreference = $oldConfirmPreference
        }

        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}

# .\JiraPS\Public\Remove-JiraVersion.ps1
function Remove-JiraVersion {
    [CmdletBinding( ConfirmImpact = 'High', SupportsShouldProcess )]
    param(
        [Parameter( Mandatory, ValueFromPipeline )]
        [ValidateNotNullOrEmpty()]
        [ValidateScript(
            {
                if (("JiraPS.Version" -notin $_.PSObject.TypeNames) -and (($_ -isnot [Int]))) {
                    $errorItem = [System.Management.Automation.ErrorRecord]::new(
                        ([System.ArgumentException]"Invalid Type for Parameter"),
                        'ParameterType.NotJiraVersion',
                        [System.Management.Automation.ErrorCategory]::InvalidArgument,
                        $_
                    )
                    $errorItem.ErrorDetails = "Wrong object type provided for Version. Expected [JiraPS.Version] or [Int], but was $($_.GetType().Name)"
                    $PSCmdlet.ThrowTerminatingError($errorItem)
                    <#
                      #ToDo:CustomClass
                      Once we have custom classes, this check can be done with Type declaration
                    #>
                }
                else {
                    return $true
                }
            }
        )]
        [Object[]]
        $Version,

        [PSCredential]
        $Credential,

        [Switch]
        $Force
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"

        if ($Force) {
            Write-DebugMessage "[Remove-JiraVersion] -Force was passed. Backing up current ConfirmPreference [$ConfirmPreference] and setting to None"
            $oldConfirmPreference = $ConfirmPreference
            $ConfirmPreference = 'None'
        }
    }

    process {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] ParameterSetName: $($PsCmdlet.ParameterSetName)"
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] PSBoundParameters: $($PSBoundParameters | Out-String)"

        foreach ($_version in $Version) {
            Write-Verbose "[$($MyInvocation.MyCommand.Name)] Processing [$_version]"
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Processing `$_version [$_version]"

            if ($_version.id) {
                $_version = $_version.Id
            }

            $versionObj = Get-JiraVersion -Id $_version -Credential $Credential -ErrorAction Stop

            $parameter = @{
                URI        = $versionObj.RestUrl
                Method     = "DELETE"
                Credential = $Credential
            }
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
            if ($PSCmdlet.ShouldProcess($versionObj.Name, "Removing Version")) {
                Invoke-JiraMethod @parameter
            }
        }
    }

    end {
        if ($Force) {
            Write-Debug "[Remove-JiraVersion] Restoring ConfirmPreference to [$oldConfirmPreference]"
            $ConfirmPreference = $oldConfirmPreference
        }

        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}

# .\JiraPS\Public\Set-JiraConfigServer.ps1
function Set-JiraConfigServer {
    [CmdletBinding()]
    [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseShouldProcessForStateChangingFunctions', '')]
    param(
        [Parameter( Mandatory )]
        [ValidateNotNullOrEmpty()]
        [Alias('Uri')]
        [Uri]
        $Server,

        [String]
        $ConfigFile
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"
    }

    process {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] ParameterSetName: $($PsCmdlet.ParameterSetName)"
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] PSBoundParameters: $($PSBoundParameters | Out-String)"

        # Using a default value for this parameter wouldn't handle all cases. We want to make sure
        # that the user can pass a $null value to the ConfigFile parameter...but if it's null, we
        # want to default to the script variable just as we would if the parameter was not
        # provided at all.

        if (-not ($ConfigFile)) {
            # This file should be in $moduleRoot/Functions/Internal, so PSScriptRoot will be $moduleRoot/Functions
            $moduleFolder = Split-Path -Path $PSScriptRoot -Parent
            $ConfigFile = Join-Path -Path $moduleFolder -ChildPath 'config.xml'
        }

        Write-Debug "[$($MyInvocation.MyCommand.Name)] Config file path: $ConfigFile"
        if (-not (Test-Path -Path $ConfigFile)) {
            Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] Creating new Config file"
            $xml = [XML] '<Config></Config>'
        }
        else {
            Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] Using existing Config file"
            $xml = New-Object -TypeName XML
            $xml.Load($ConfigFile)
        }

        $xmlConfig = $xml.DocumentElement
        if ($xmlConfig.LocalName -ne 'Config') {
            $errorItem = [System.Management.Automation.ErrorRecord]::new(
                ([System.ArgumentException]"Invalid Document"),
                'InvalidObject.InvalidDocument',
                [System.Management.Automation.ErrorCategory]::InvalidData,
                $_
            )
            $errorItem.ErrorDetails = "Unexpected document element [$($xmlConfig.LocalName)] in configuration file. You may need to delete the config file and recreate it using this function."
            $PSCmdlet.ThrowTerminatingError($errorItem)
        }

        $fixedServer = $Server.AbsoluteUri.Trim('/')

        if ($xmlConfig.Server) {
            $xmlConfig.Server = $fixedServer
        }
        else {
            $xmlServer = $xml.CreateElement('Server')
            $xmlServer.InnerText = $fixedServer
            [void] $xmlConfig.AppendChild($xmlServer)
        }

        try {
            $xml.Save($ConfigFile)
        }
        catch {
            throw $_
        }
    }

    end {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}

# .\JiraPS\Public\Set-JiraIssue.ps1
function Set-JiraIssue {
    [CmdletBinding( SupportsShouldProcess )]
    param(
        [Parameter( Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName )]
        [ValidateNotNullOrEmpty()]
        [ValidateScript(
            {
                if (("JiraPS.Issue" -notin $_.PSObject.TypeNames) -and (($_ -isnot [String]))) {
                    $errorItem = [System.Management.Automation.ErrorRecord]::new(
                        ([System.ArgumentException]"Invalid Type for Parameter"),
                        'ParameterType.NotJiraIssue',
                        [System.Management.Automation.ErrorCategory]::InvalidArgument,
                        $_
                    )
                    $errorItem.ErrorDetails = "Wrong object type provided for Issue. Expected [JiraPS.Issue] or [String], but was $($_.GetType().Name)"
                    $PSCmdlet.ThrowTerminatingError($errorItem)
                    <#
                      #ToDo:CustomClass
                      Once we have custom classes, this check can be done with Type declaration
                    #>
                }
                else {
                    return $true
                }
            }
        )]
        [Alias('Key')]
        [Object[]]
        $Issue,

        [String]
        $Summary,

        [String]
        $Description,

        [Alias('FixVersions')]
        [String[]]
        $FixVersion,

        [Object]
        $Assignee,

        [String[]]
        $Label,

        [Hashtable]
        $Fields,

        [String]
        $AddComment,

        [PSCredential]
        $Credential,

        [Switch]
        $PassThru
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"

        $fieldNames = $Fields.Keys
        if (-not ($Summary -or $Description -or $Assignee -or $Label -or $FixVersion -or $fieldNames -or $AddComment)) {
            $errorMessage = @{
                Category         = "InvalidArgument"
                CategoryActivity = "Validating Arguments"
                Message          = "The parameters provided do not change the Issue. No action will be performed"
            }
            Write-Error @errorMessage
            return
        }

        if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey("Assignee")) {
            if ($Assignee -eq 'Unassigned') {
                <#
                  #ToDo:Deprecated
                  This behavior should be deprecated
                #>
                Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] 'Unassigned' String passed. Issue will be assigned to no one."
                $assigneeString = ""
                $validAssignee = $true
            }
            else {
                if ($assigneeObj = Get-JiraUser -UserName $Assignee -Credential $Credential) {
                    Write-Debug "[$($MyInvocation.MyCommand.Name)] User found (name=[$($assigneeObj.Name)],RestUrl=[$($assigneeObj.RestUrl)])"
                    $assigneeString = $assigneeObj.Name
                    $validAssignee = $true
                }
                else {
                    $errorItem = [System.Management.Automation.ErrorRecord]::new(
                        ([System.ArgumentException]"Invalid value for Parameter"),
                        'ParameterValue.InvalidAssignee',
                        [System.Management.Automation.ErrorCategory]::InvalidArgument,
                        $Assignee
                    )
                    $errorItem.ErrorDetails = "Unable to validate Jira user [$Assignee]. Use Get-JiraUser for more details."
                    $PSCmdlet.ThrowTerminatingError($errorItem)
                }
            }
        }
    }

    process {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] ParameterSetName: $($PsCmdlet.ParameterSetName)"
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] PSBoundParameters: $($PSBoundParameters | Out-String)"

        foreach ($_issue in $Issue) {
            Write-Verbose "[$($MyInvocation.MyCommand.Name)] Processing [$_issue]"
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Processing `$_issue [$_issue]"

            # Find the proper object for the Issue
            $issueObj = Resolve-JiraIssueObject -InputObject $_issue -Credential $Credential

            $issueProps = @{
                'update' = @{}
            }

            if ($Summary) {
                # Update properties need to be passed to JIRA as arrays
                $issueProps.update["summary"] = @(@{ 'set' = $Summary })
            }

            if ($Description) {
                $issueProps.update["description"] = @(@{ 'set' = $Description })
            }

            if ($FixVersion) {
                $fixVersionSet = [System.Collections.ArrayList]@()
                foreach ($item in $FixVersion) {
                    $null = $fixVersionSet.Add( @{ 'name' = $item } )
                }
                $issueProps.update["fixVersions"] = @( @{ set = $fixVersionSet } )
            }

            if ($AddComment) {
                $issueProps.update["comment"] = @(
                    @{
                        'add' = @{
                            'body' = $AddComment
                        }
                    }
                )
            }

            if ($Fields) {
                Write-Debug "[$($MyInvocation.MyCommand.Name)] Resolving `$Fields"
                foreach ($_key in $Fields.Keys) {
                    $name = $_key
                    $value = $Fields.$_key

                    $field = Get-JiraField -Field $name -Credential $Credential -ErrorAction Stop

                    # For some reason, this was coming through as a hashtable instead of a String,
                    # which was causing ConvertTo-Json to crash later.
                    # Not sure why, but this forces $id to be a String and not a hashtable.
                    $id = [string]$field.Id
                    $issueProps.update[$id] = @(@{ 'set' = $value })
                }
            }

            if ($validAssignee) {
                $assigneeProps = @{
                    'name' = $assigneeString
                }
            }

            if ( @($issueProps.update.Keys).Count -gt 0 ) {
                Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] Updating issue fields"

                $parameter = @{
                    URI        = $issueObj.RestUrl
                    Method     = "PUT"
                    Body       = ConvertTo-Json -InputObject $issueProps -Depth 10
                    Credential = $Credential
                }
                Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
                if ($PSCmdlet.ShouldProcess($issueObj.Key, "Updating Issue")) {
                    Invoke-JiraMethod @parameter
                }
            }

            if ($assigneeProps) {
                Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] Updating issue assignee"
                # Jira handles assignee differently; you can't change it from the default "edit issues" screen unless
                # you customize the "Edit Issue" screen.

                $parameter = @{
                    URI        = "{0}/assignee" -f $issueObj.RestUrl
                    Method     = "PUT"
                    Body       = ConvertTo-Json -InputObject $assigneeProps
                    Credential = $Credential
                }
                Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
                if ($PSCmdlet.ShouldProcess($issueObj.Key, "Updating Issue [Assignee] from JIRA")) {
                    Invoke-JiraMethod @parameter
                }
            }

            if ($Label) {
                Set-JiraIssueLabel -Issue $issueObj -Set $Label -Credential $Credential
            }

            if ($PassThru) {
                Get-JiraIssue -Key $issueObj.Key -Credential $Credential
            }
        }
    }

    end {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}

# .\JiraPS\Public\Set-JiraIssueLabel.ps1
function Set-JiraIssueLabel {
    [CmdletBinding( SupportsShouldProcess, DefaultParameterSetName = 'ReplaceLabels' )]
    param(
        [Parameter( Position = 0, Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName )]
        [ValidateNotNullOrEmpty()]
        [ValidateScript(
            {
                if (("JiraPS.Issue" -notin $_.PSObject.TypeNames) -and (($_ -isnot [String]))) {
                    $errorItem = [System.Management.Automation.ErrorRecord]::new(
                        ([System.ArgumentException]"Invalid Type for Parameter"),
                        'ParameterType.NotJiraIssue',
                        [System.Management.Automation.ErrorCategory]::InvalidArgument,
                        $_
                    )
                    $errorItem.ErrorDetails = "Wrong object type provided for Issue. Expected [JiraPS.Issue] or [String], but was $($_.GetType().Name)"
                    $PSCmdlet.ThrowTerminatingError($errorItem)
                    <#
                      #ToDo:CustomClass
                      Once we have custom classes, this check can be done with Type declaration
                    #>
                }
                else {
                    return $true
                }
            }
        )]
        [Alias('Key')]
        [Object[]]
        $Issue,

        [Parameter( Mandatory, ParameterSetName = 'ReplaceLabels' )]
        [Alias('Label', 'Replace')]
        [String[]]
        $Set,

        [Parameter( ParameterSetName = 'ModifyLabels' )]
        [String[]]
        $Add,

        [Parameter( ParameterSetName = 'ModifyLabels' )]
        [String[]]
        $Remove,

        [Parameter( Mandatory, ParameterSetName = 'ClearLabels' )]
        [Switch]
        $Clear,

        [PSCredential]
        $Credential,

        [Switch]
        $PassThru
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"
    }

    process {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] ParameterSetName: $($PsCmdlet.ParameterSetName)"
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] PSBoundParameters: $($PSBoundParameters | Out-String)"

        foreach ($_issue in $Issue) {
            Write-Verbose "[$($MyInvocation.MyCommand.Name)] Processing [$_issue]"
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Processing `$_issue [$_issue]"

            # Find the proper object for the Issue
            $issueObj = Resolve-JiraIssueObject -InputObject $_issue -Credential $Credential

            $labels = [System.Collections.ArrayList]@($issueObj.labels)

            # As of JIRA 6.4, the Add and Remove verbs in the REST API for
            # updating issues do not support arrays of parameters - you
            # need to pass a single label to add or remove per API call.

            # Instead, we'll do some fancy footwork with the existing
            # issue object and use the Set verb for everything, so we only
            # have to make one call to JIRA.
            switch ($PSCmdlet.ParameterSetName) {
                'ClearLabels' {
                    Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] Clearing all labels"
                    $labels = [System.Collections.ArrayList]@()
                }
                'ReplaceLabels' {
                    Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] Replacing existing labels"
                    $labels = [System.Collections.ArrayList]$Set
                }
                'ModifyLabels' {
                    if ($Add) {
                        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] Adding labels"
                        $null = $labels.Add($Add)
                    }
                    if ($Remove) {
                        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] Removing labels"
                        foreach ($item in $Remote) {
                            $labels.Remove($item)
                        }
                    }
                }
            }

            $requestBody = @{
                'update' = @{
                    'labels' = @(
                        @{
                            'set' = @($labels)
                        }
                    )
                }
            }

            $parameter = @{
                URI        = $issueObj.RestURL
                Method     = "PUT"
                Body       = ConvertTo-Json -InputObject $requestBody -Depth 4
                Credential = $Credential
            }
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
            if ($PSCmdlet.ShouldProcess($IssueObj.Key, "Updating Issue labels")) {
                Invoke-JiraMethod @parameter

                if ($PassThru) {
                    Get-JiraIssue -Key $issueObj.Key -Credential $Credential
                }
            }
        }
    }

    end {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}

# .\JiraPS\Public\Set-JiraUser.ps1
function Set-JiraUser {
    [CmdletBinding( SupportsShouldProcess, DefaultParameterSetName = 'ByNamedParameters' )]
    param(
        [Parameter( Position = 0, Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName )]
        [ValidateNotNullOrEmpty()]
        [ValidateScript(
            {
                if (("JiraPS.User" -notin $_.PSObject.TypeNames) -and (($_ -isnot [String]))) {
                    $errorItem = [System.Management.Automation.ErrorRecord]::new(
                        ([System.ArgumentException]"Invalid Type for Parameter"),
                        'ParameterType.NotJiraUser',
                        [System.Management.Automation.ErrorCategory]::InvalidArgument,
                        $_
                    )
                    $errorItem.ErrorDetails = "Wrong object type provided for User. Expected [JiraPS.User] or [String], but was $($_.GetType().Name)"
                    $PSCmdlet.ThrowTerminatingError($errorItem)
                    <#
                      #ToDo:CustomClass
                      Once we have custom classes, this check can be done with Type declaration
                    #>
                }
                else {
                    return $true
                }
            }
        )]
        [Alias('UserName')]
        [Object[]]
        $User,

        [Parameter( ParameterSetName = 'ByNamedParameters' )]
        [ValidateNotNullOrEmpty()]
        [String]
        $DisplayName,

        [Parameter( ParameterSetName = 'ByNamedParameters' )]
        [ValidateNotNullOrEmpty()]
        [ValidateScript(
            {
                if ($_ -match '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$') {
                    return $true
                }
                else {
                    $errorItem = [System.Management.Automation.ErrorRecord]::new(
                        ([System.ArgumentException]"Invalid Argument"),
                        'ParameterValue.NotEmail',
                        [System.Management.Automation.ErrorCategory]::InvalidArgument,
                        $Issue
                    )
                    $errorItem.ErrorDetails = "The value provided does not look like an email address."
                    $PSCmdlet.ThrowTerminatingError($errorItem)
                    return $false
                }
            }
        )]
        [String]
        $EmailAddress,

        [Parameter( Position = 1, Mandatory, ParameterSetName = 'ByHashtable' )]
        [Hashtable]
        $Property,

        [PSCredential]
        $Credential,

        [Switch]
        $PassThru
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"

        $server = Get-JiraConfigServer -ErrorAction Stop

        $resourceURi = "$server/rest/api/latest/user?username={0}"
    }

    process {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] ParameterSetName: $($PsCmdlet.ParameterSetName)"
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] PSBoundParameters: $($PSBoundParameters | Out-String)"

        foreach ($_user in $User) {
            Write-Verbose "[$($MyInvocation.MyCommand.Name)] Processing [$_user]"
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Processing `$_user [$_user]"

            $userObj = Get-JiraUser -UserName $_user -Credential $Credential -ErrorAction Stop

            $requestBody = @{}

            switch ($PSCmdlet.ParameterSetName) {
                'ByNamedParameters' {
                    if (-not ($DisplayName -or $EmailAddress)) {
                        $errorMessage = @{
                            Category         = "InvalidArgument"
                            CategoryActivity = "Validating Arguments"
                            Message          = "The parameters provided do not change the User. No action will be performed"
                        }
                        Write-Error @errorMessage
                        return
                    }

                    if ($DisplayName) {
                        $requestBody.displayName = $DisplayName
                    }

                    if ($EmailAddress) {
                        $requestBody.emailAddress = $EmailAddress
                    }
                }
                'ByHashtable' {
                    $requestBody = $Property
                }
            }

            $parameter = @{
                URI        = $resourceURi -f $userObj.Name
                Method     = "PUT"
                Body       = ConvertTo-Json -InputObject $requestBody -Depth 4
                Credential = $Credential
            }
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
            if ($PSCmdlet.ShouldProcess($UserObj.DisplayName, "Updating user")) {
                $result = Invoke-JiraMethod @parameter

                if ($PassThru) {
                    Write-Output (Get-JiraUser -inputObject $result)
                }
            }
        }
    }

    end {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}

# .\JiraPS\Public\Set-JiraVersion.ps1
function Set-JiraVersion {
    <#
    .SYNOPSIS
        Modifies an existing Version in JIRA
    .DESCRIPTION
        This function modifies the Version for an existing Project in JIRA.
    .EXAMPLE
        Get-JiraVersion -Project $Project -Name "Old-Name" | Set-JiraVersion -Name 'New-Name'
        This example assigns the modifies the existing version with a new name 'New-Name'.
    .EXAMPLE
        Get-JiraVersion -ID 162401 | Set-JiraVersion -Description 'Descriptive String'
        This example assigns the modifies the existing version with a new name 'New-Name'.
     .INPUTS
        [JiraPS.Version]
     .OUTPUTS
        [JiraPS.Version]
     .NOTES
       This function requires either the -Credential parameter to be passed or a persistent JIRA session. See New-JiraSession for more details.  If neither are supplied, this function will run with anonymous access to JIRA.
    #>
    [CmdletBinding( SupportsShouldProcess )]
    param(
        # Version to be changed
        [Parameter( Mandatory, ValueFromPipeline )]
        [ValidateNotNullOrEmpty()]
        [ValidateScript(
            {
                if (("JiraPS.Version" -notin $_.PSObject.TypeNames) -and (($_ -isnot [String]))) {
                    $errorItem = [System.Management.Automation.ErrorRecord]::new(
                        ([System.ArgumentException]"Invalid Type for Parameter"),
                        'ParameterType.NotJiraVersion',
                        [System.Management.Automation.ErrorCategory]::InvalidArgument,
                        $_
                    )
                    $errorItem.ErrorDetails = "Wrong object type provided for Version. Expected [JiraPS.Version] or [String], but was $($_.GetType().Name)"
                    $PSCmdlet.ThrowTerminatingError($errorItem)
                    <#
                      #ToDo:CustomClass
                      Once we have custom classes, this check can be done with Type declaration
                    #>
                }
                else {
                    return $true
                }
            }
        )]
        [Object[]]
        $Version,

        # New Name of the Version.
        [String]
        $Name,

        # New Description of the Version.
        [String]
        $Description,

        # New value for Archived.
        [Bool]
        $Archived,

        # New value for Released.
        [Bool]
        $Released,

        # New Date of the release.
        [DateTime]
        $ReleaseDate,

        # New Date of the user release.
        [DateTime]
        $StartDate,

        # The new Project where this version should be in.
        # This can be the ID of the Project, or the Project Object
        [ValidateScript(
            {
                if (("JiraPS.Project" -notin $_.PSObject.TypeNames) -and (($_ -isnot [String]))) {
                    $errorItem = [System.Management.Automation.ErrorRecord]::new(
                        ([System.ArgumentException]"Invalid Type for Parameter"),
                        'ParameterType.NotJiraProject',
                        [System.Management.Automation.ErrorCategory]::InvalidArgument,
                        $_
                    )
                    $errorItem.ErrorDetails = "Wrong object type provided for Project. Expected [JiraPS.Project] or [String], but was $($_.GetType().Name)"
                    $PSCmdlet.ThrowTerminatingError($errorItem)
                    <#
                      #ToDo:CustomClass
                      Once we have custom classes, this check can be done with Type declaration
                    #>
                }
                else {
                    return $true
                }
            }
        )]
        [Object]
        $Project,

        # Credentials to use to connect to JIRA.
        # If not specified, this function will use anonymous access.
        [PSCredential]
        $Credential
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"
    }

    process {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] ParameterSetName: $($PsCmdlet.ParameterSetName)"
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] PSBoundParameters: $($PSBoundParameters | Out-String)"

        foreach ($_version in $Version) {
            Write-Verbose "[$($MyInvocation.MyCommand.Name)] Processing [$_version]"
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Processing `$_version [$_version]"

            $versionObj = Get-JiraVersion -Id $_version.Id -Credential $Credential -ErrorAction Stop

            $requestBody = @{}

            if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey("Name")) {
                $requestBody["name"] = $Name
            }
            if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey("Description")) {
                $requestBody["description"] = $Description
            }
            if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey("Archived")) {
                $requestBody["archived"] = $Archived
            }
            if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey("Released")) {
                $requestBody["released"] = $Released
            }
            if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey("Project")) {
                $projectObj = Get-JiraProject -Project $Project -Credential $Credential -ErrorAction Stop

                $requestBody["projectId"] = $projectObj.Id
            }
            if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey("ReleaseDate")) {
                $requestBody["releaseDate"] = $ReleaseDate.ToString('yyyy-MM-dd')
            }
            if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey("StartDate")) {
                $requestBody["startDate"] = $StartDate.ToString('yyyy-MM-dd')
            }

            $parameter = @{
                URI        = $versionObj.RestUrl
                Method     = "PUT"
                Body       = ConvertTo-Json -InputObject $requestBody
                Credential = $Credential
            }
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
            if ($PSCmdlet.ShouldProcess($Name, "Updating Version on JIRA")) {
                $result = Invoke-JiraMethod @parameter

                Write-Output (ConvertTo-JiraVersion -InputObject $result)
            }
        }
    }

    end {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}


