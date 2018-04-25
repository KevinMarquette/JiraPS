---
external help file: JiraPS-help.xml
layout: documentation
locale: en-US
Module Name: JiraPS
online version: https://atlassianps.org/docs/JiraPS/commands/Get-JiraPriority/
permalink: /docs/JiraPS/commands/Get-JiraPriority/
schema: 2.0.0
---

# Get-JiraPriority

## SYNOPSIS

Returns information about the available priorities in JIRA.

## SYNTAX

### _All (Default)
```
Get-JiraPriority [-Credential <PSCredential>] [<CommonParameters>]
```

### _Search
```
Get-JiraPriority [-Id] <Int32[]> [-Credential <PSCredential>] [<CommonParameters>]
```

## DESCRIPTION

This function retrieves all the available Priorities on the JIRA server an returns them as `JiraPS.Priority`.

This function can restrict the output to a subset of the available IssueTypes if told so.

## EXAMPLES

### EXAMPLE 1

```powershell
Get-JiraPriority
```

Description  
 -----------  
This example returns all the IssueTypes on the JIRA server.

### EXAMPLE 2

```powershell
Get-JiraPriority -ID 1
```

Description  
 -----------  
This example returns only the Priority with ID 1.

## PARAMETERS

### -Credential

Credentials to use to connect to JIRA.  
If not specified, this function will use anonymous access.

```yaml
Type: PSCredential
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Id

ID of the priority to get.

```yaml
Type: Int32[]
Parameter Sets: _Search
Aliases:

Required: True
Position: 0
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see about_CommonParameters (http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### [JiraPS.Priority]

## NOTES

This function requires either the `-Credential` parameter to be passed or a persistent JIRA session.
See `New-JiraSession` for more details.
If neither are supplied, this function will run with anonymous access to JIRA.

Remaining operations for `priority` have not yet been implemented in the module.

## RELATED LINKS
