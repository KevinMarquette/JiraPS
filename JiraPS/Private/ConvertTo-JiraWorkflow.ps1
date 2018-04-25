function ConvertTo-JiraWorkflow {
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            Position = 0,
            ValueFromPipeline = $true
        )]
        [PSObject[]] $InputObject
    )

    process {
        foreach ($i in $InputObject) {
            $props = @{
                'Name'        = $i.name
                'Description' = $i.description
                'Steps'       = $i.Steps
                'Default'     = $i.Default
            }
            $result = New-Object -TypeName PSObject -Property $props
            $result.PSObject.TypeNames.Insert(0, 'JiraPS.Workflow')
            $result | Add-Member -MemberType ScriptMethod -Name "ToString" -Force -Value {
                Write-Output "$($this.Name)"
            }
            Write-Output $result
        }
    }

    end {
    }
}
