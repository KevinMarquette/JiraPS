---
external help file: JiraPS-help.xml
layout: documentation
locale: en-US
Module Name: JiraPS
online version: https://atlassianps.org/docs/JiraPS/commands/Set-JiraVersion/
permalink: /docs/JiraPS/commands/Set-JiraVersion/
schema: 2.0.0
---

# Set-JiraVersion

## SYNOPSIS

Modifies an existing Version in JIRA

## SYNTAX

```
Set-JiraVersion [-Version] <Object[]> [[-Name] <String>] [[-Description] <String>] [[-Archived] <Boolean>]
 [[-Released] <Boolean>] [[-ReleaseDate] <DateTime>] [[-StartDate] <DateTime>] [[-Project] <Object>]
 [[-Credential] <PSCredential>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION

This function modifies the Version for an existing Project in JIRA.

## EXAMPLES

### EXAMPLE 1

```powershell
Get-JiraVersion -Project $Project -Name "Old-Name" | Set-JiraVersion -Name 'New-Name'
```

Description  
 -----------  
This example assigns the modifies the existing version with a new name 'New-Name'.

### EXAMPLE 2

```powershell
Get-JiraVersion -ID 162401 | Set-JiraVersion -Description 'Descriptive String'
```

Description  
 -----------  
This example assigns the modifies the existing version with a new name 'New-Name'.

## PARAMETERS

### -Archived

New value for Archived.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Credential

Credentials to use to connect to JIRA.  
If not specified, this function will use anonymous access.

```yaml
Type: PSCredential
Parameter Sets: (All)
Aliases:

Required: False
Position: 9
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Description

New Description of the Version.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Name

New Name of the Version.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Project

The new Project where this version should be in.

This can be the ID of the Project, or the Project Object

```yaml
Type: Object
Parameter Sets: (All)
Aliases:

Required: False
Position: 8
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Released

New value for Released.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -ReleaseDate

New Date of the release.

```yaml
Type: DateTime
Parameter Sets: (All)
Aliases:

Required: False
Position: 6
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -StartDate

New Date of the user release.

```yaml
Type: DateTime
Parameter Sets: (All)
Aliases:

Required: False
Position: 7
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Version

Version to be changed

```yaml
Type: Object[]
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
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

### [JiraPS.Version]

## OUTPUTS

### [JiraPS.Version]

## NOTES

This function requires either the `-Credential` parameter to be passed or a persistent JIRA session.
See `New-JiraSession` for more details.
If neither are supplied, this function will run with anonymous access to JIRA.

## RELATED LINKS

[Get-JiraVersion](../Get-JiraVersion/)

[New-JiraVersion](../New-JiraVersion/)

[Set-JiraVersion](../Set-JiraVersion/)
