---
external help file: JiraPS-help.xml
layout: documentation
locale: en-US
Module Name: JiraPS
online version: https://atlassianps.org/docs/JiraPS/commands/Get-JiraIssueEditMetadata/
permalink: /docs/JiraPS/commands/Get-JiraIssueEditMetadata/
schema: 2.0.0
---

# Get-JiraIssueEditMetadata

## SYNOPSIS

Returns metadata required to change an issue in JIRA

## SYNTAX

```
Get-JiraIssueEditMetadata [-Issue] <String> [[-Credential] <PSCredential>] [<CommonParameters>]
```

## DESCRIPTION

This function returns metadata required to update an issue in JIRA - the fields that can be defined in the process of updating an issue.
This can be used to identify custom fields in order to pass them to `Set-JiraIssue`.

This function is particularly useful when your JIRA instance includes custom fields that are marked as mandatory.

## EXAMPLES

### EXAMPLE 1

```powershell
Get-JiraIssueEditMetadata -Issue "TEST-001"
```

This example returns the fields available when updating the issue "TEST-001".

### EXAMPLE 2

```powershell
Get-JiraIssueEditMetadata -Issue "TEST-001" | ? {$_.Required -eq $true}
```

This example returns fields available when updating the issue "TEST-001".
It then uses `Where-Object` (aliased by the question mark) to filter only the fields that are required.

## PARAMETERS

### -Credential

Credentials to use to connect to JIRA.  
If not specified, this function will use anonymous access.

```yaml
Type: PSCredential
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Issue

Issue id or key of the reference issue.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 0
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see about_CommonParameters (http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### [JiraPS.Field]

## NOTES

This function requires either the `-Credential` parameter to be passed or a persistent JIRA session.
See `New-JiraSession` for more details.
If neither are supplied, this function will run with anonymous access to JIRA.

## RELATED LINKS

[about_JiraPS_UpdatingIssues](../../about/updating-issues.html)

[Get-JiraField](../Get-JiraField/)

[Set-JiraIssue](../Set-JiraIssue/)
