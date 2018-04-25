---
external help file: JiraPS-help.xml
layout: documentation
locale: en-US
Module Name: JiraPS
online version: https://atlassianps.org/docs/JiraPS/commands/Get-JiraIssueComment/
permalink: /docs/JiraPS/commands/Get-JiraIssueComment/
schema: 2.0.0
---

# Get-JiraIssueComment

## SYNOPSIS

Returns comments on an issue in JIRA.

## SYNTAX

```
Get-JiraIssueComment [-Issue] <Object> [[-Credential] <PSCredential>] [<CommonParameters>]
```

## DESCRIPTION

This function obtains comments from existing issues in JIRA.

## EXAMPLES

### EXAMPLE 1

```powershell
Get-JiraIssueComment -Key TEST-001
```

Description  
 -----------  
This example returns all comments posted to issue TEST-001.

### EXAMPLE 2

```powershell
Get-JiraIssue TEST-002 | Get-JiraIssueComment
```

Description  
 -----------  
This example illustrates use of the pipeline to return all comments on issue TEST-002.

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

JIRA issue to check for comments.

Can be a `JiraPS.Issue` object, issue key, or internal issue ID.

```yaml
Type: Object
Parameter Sets: (All)
Aliases: Key

Required: True
Position: 0
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see about_CommonParameters (http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### [JiraPS.Issue] / [String]

## OUTPUTS

### [JiraPS.Comment]

## NOTES

This function requires either the `-Credential` parameter to be passed or a persistent JIRA session.
See `New-JiraSession` for more details.
If neither are supplied, this function will run with anonymous access to JIRA.

## RELATED LINKS

[Add-JiraIssueComment](../Add-JiraIssueComment/)

[Get-JiraIssue](../Get-JiraIssue/)
