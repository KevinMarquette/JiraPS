function Get-JiraField
{
    [CmdletBinding( DefaultParameterSetName = '_All' )]
    param(
        [Parameter( Position = 0, Mandatory, ValueFromPipeline, ParameterSetName = '_Search' )]
        [String[]]
        $Field,

        [PSCredential]
        $Credential
    )

    begin
    {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"

        $server = Get-JiraConfigServer -ErrorAction Stop

        $resourceURi = "$server/rest/api/latest/field"
    }

    process
    {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] ParameterSetName: $($PsCmdlet.ParameterSetName)"
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] PSBoundParameters: $($PSBoundParameters | Out-String)"

        switch ($PSCmdlet.ParameterSetName)
        {
            '_All'
            {
                $parameter = @{
                    URI        = $resourceURi
                    Method     = "GET"
                    Credential = $Credential
                }
                Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
                $result = Invoke-JiraMethod @parameter

                Write-Output (ConvertTo-JiraField -InputObject $result)
            }
            '_Search'
            {
                foreach ($_field in $Field)
                {
                    Write-Verbose "[$($MyInvocation.MyCommand.Name)] Processing [$_field]"
                    Write-Debug "[$($MyInvocation.MyCommand.Name)] Processing `$_field [$_field]"
                    If ($script:jiraFieldCacheTimeout)
                    {
                        $cacheValid = [datetime]::UtcNow - $script:jiraFieldCacheTimeout
                        If ($cacheValid.TotalMinutes -gt 5)
                        {
                            $process = $true
                        }
                        else
                        {
                            $process = $false
                        }
                    }
                    Else
                    {
                        $process = $true
                    }
                    If ($process)
                    {
                        $script:allFields = Get-JiraField -Credential $Credential
                        $script:jiraFieldCacheTimeout = [datetime]::UtcNow
                    }
                    Write-Output ($allFields | Where-Object -FilterScript {($_.Id -eq $_field) -or ($_.Name -like $_field)})
                }
            }
        }
    }

    end
    {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}
