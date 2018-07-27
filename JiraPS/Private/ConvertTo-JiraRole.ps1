function ConvertTo-JiraRole
{
    [CmdletBinding()]
    param(
        [Parameter( ValueFromPipeline )]
        [PSObject]
        $InputObject
    )

    process
    {
        If ($InputObject.self)
        {
            $props = @{
                'Role'        = $InputObject.name
                'RoleID'      = $InputObject.id
                'description' = $InputObject.description
                'members'     = ($InputObject.actors | ConvertTo-JiraUser)
            }
            $result = New-Object -TypeName psobject -Property $props
            $result.PSObject.TypeNames.Insert(0, 'JiraPS.Role')
            $result | Add-Member -MemberType ScriptMethod -Name "ToString" -Force -Value {
                Write-Output "$($this.Name)"
            }

            Write-Output $result
        }
        Else
        {
            foreach ($role in $InputObject.PSObject.properties.Name)
            {
                $props = @{
                    'Role'   = $role
                    'RoleID' = [uri] $InputObject.$role | Select-Object -ExpandProperty segments | Select-Object -Last 1
                }
                $result = New-Object -TypeName psobject -Property $props
                $result.PSObject.TypeNames.Insert(0, 'JiraPS.Role')
                $result | Add-Member -MemberType ScriptMethod -Name "ToString" -Force -Value {
                    Write-Output "$($this.Name)"
                }

                Write-Output $result
            }
        }
    }
}
