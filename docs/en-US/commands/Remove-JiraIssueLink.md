---
external help file: JiraPS-help.xml
layout: documentation
locale: en-US
Module Name: JiraPS
online version: https://atlassianps.org/docs/JiraPS/commands/Remove-JiraIssueLink/
permalink: /docs/JiraPS/commands/Remove-JiraIssueLink/
schema: 2.0.0
---

# Remove-JiraIssueLink

## SYNOPSIS

Removes a issue link from a JIRA issue

## SYNTAX

```
Remove-JiraIssueLink [-IssueLink] <Object[]> [[-Credential] <PSCredential>] [-WhatIf] [-Confirm]
 [<CommonParameters>]
```

## DESCRIPTION

This function removes a issue link from a JIRA issue.

## EXAMPLES

### EXAMPLE 1

```powershell
Remove-JiraIssueLink 1234,2345
```

Removes two issue links with id 1234 and 2345

### EXAMPLE 2

```powershell
Get-JiraIssue -Query "project = Project1 AND label = lingering" | Remove-JiraIssueLink
```

Removes all issue links for all issues in project Project1 and that have a label "lingering"

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

### -IssueLink

IssueLink to delete

If a `JiraPS.Issue` is provided, all issueLinks will be deleted.

```yaml
Type: Object[]
Parameter Sets: (All)
Aliases:

Required: True
Position: 0
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### -Confirm

Prompts you for confirmation before running the cmdlet.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: cf

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -WhatIf

Shows what would happen if the cmdlet runs.
The cmdlet is not run.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: wi

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see about_CommonParameters (http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### [JiraPS.Issue[]] / [JiraPS.IssueLink[]]

## OUTPUTS

## NOTES

This function requires either the `-Credential` parameter to be passed or a persistent JIRA session.
See `New-JiraSession` for more details.
If neither are supplied, this function will run with anonymous access to JIRA.

## RELATED LINKS

[Add-JiraIssueLink](../Add-JiraIssueLink/)

[Get-JiraIssue](../Get-JiraIssue/)

[Get-JiraIssueLink](../Get-JiraIssueLink/)
