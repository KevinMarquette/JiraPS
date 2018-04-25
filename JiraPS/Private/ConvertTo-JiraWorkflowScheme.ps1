function ConvertTo-JiraWorkflowScheme {
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
                'ID'                 = $i.id
                'Name'               = $i.name
                'Description'        = $i.description
                "DefaultWorkflow"    = $i.DefaultWorkflow
                'IssueTypesMappings' = $i.IssueTypesMappings
                'Draft'              = $i.Draft
                'RestUrl'            = $i.self
                'IssueTypes'         = $i.IssueTypes
            }
            $result = New-Object -TypeName PSObject -Property $props
            $result.PSObject.TypeNames.Insert(0, 'JiraPS.WorkflowScheme')
            $result | Add-Member -MemberType ScriptMethod -Name "ToString" -Force -Value {
                Write-Output "$($this.Name)"
            }
            Write-Output $result
        }
    }

    end {
    }
}
