---
external help file: JiraPS-help.xml
layout: documentation
locale: en-US
Module Name: JiraPS
online version: https://atlassianps.org/docs/JiraPS/commands/Get-JiraProject/
permalink: /docs/JiraPS/commands/Get-JiraProject/
schema: 2.0.0
---

# Get-JiraProject

## SYNOPSIS

Returns a project from Jira

## SYNTAX

### _All (Default)
```
Get-JiraProject [-Credential <PSCredential>] [<CommonParameters>]
```

### _Search
```
Get-JiraProject [-Project] <String[]> [-Credential <PSCredential>] [<CommonParameters>]
```

## DESCRIPTION

This function returns information regarding a specified project from Jira.

If the Project parameter is not supplied,
it will return information about all projects the given user is authorized to view.

The `-Project` parameter will accept either a project ID or a project key.

## EXAMPLES

### EXAMPLE 1

```powershell
Get-JiraProject -Project TEST -Credential $cred
```

Description  
 -----------  
Returns information about the project TEST

### EXAMPLE 2

```powershell
Get-JiraProject 2 -Credential $cred
```

Description  
 -----------  
Returns information about the project with ID 2

### EXAMPLE 3

```powershell
Get-JiraProject
```

Description  
 -----------  
Returns information about all projects the user is authorized to view

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

### -Project

The Project ID or project key of a project to search.

```yaml
Type: String[]
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

### [JiraPS.Project]

## NOTES

This function requires either the `-Credential` parameter to be passed or a persistent JIRA session.
See `New-JiraSession` for more details.
If neither are supplied, this function will run with anonymous access to JIRA.

Remaining operations for `project` have not yet been implemented in the module.

## RELATED LINKS
