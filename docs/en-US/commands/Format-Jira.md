---
external help file: JiraPS-help.xml
layout: documentation
locale: en-US
Module Name: JiraPS
online version: https://atlassianps.org/docs/JiraPS/commands/Format-Jira/
permalink: /docs/JiraPS/commands/Format-Jira/
schema: 2.0.0
---

# Format-Jira

## SYNOPSIS

Converts an object into a table formatted according to JIRA's markdown syntax

## SYNTAX

```
Format-Jira [-InputObject] <PSObject[]> [[-Property] <Object[]>] [<CommonParameters>]
```

## DESCRIPTION

This function converts a PowerShell object into a table using JIRA's markdown syntax.
This can then be added to a JIRA issue description or comment.

## EXAMPLES

### EXAMPLE 1

```powershell
Get-Process | Format-Jira | Add-JiraIssueComment -Issue TEST-001
```

Description  
 -----------  
This example illustrates converting the output from `Get-Process` into a JIRA table, which is then added as a comment to issue TEST-001.

### EXAMPLE 2

```powershell
Get-Process chrome | Format-Jira Name,Id,VM
```

Description  
 -----------  
This example obtains all Google Chrome processes, then creates a JIRA table with only the Name,ID, and VM properties of each object.

## PARAMETERS

### -InputObject

Object to format.

```yaml
Type: PSObject[]
Parameter Sets: (All)
Aliases:

Required: True
Position: 0
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### -Property

List of properties to display.
If omitted, only the default properties will be shown.

To display all properties, use `-Property *`.

```yaml
Type: Object[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see about_CommonParameters (http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### [System.Object[]]

accepts any Object via pipeline

## OUTPUTS

### [System.String]

## NOTES

Like the native `Format-*` cmdlets, this is a destructive operation.

Remember to "filter left, format right!"

## RELATED LINKS
