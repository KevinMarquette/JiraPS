---
external help file: JiraPS-help.xml
Module Name: JiraPS
online version:
schema: 2.0.0
---

# Get-JiraVersion

## SYNOPSIS
{{Fill in the Synopsis}}

## SYNTAX

### byId (Default)
```
Get-JiraVersion -Id <Int32[]> [-Credential <PSCredential>] [<CommonParameters>]
```

### byInputVersion
```
Get-JiraVersion [-InputVersion] <Object> [-Credential <PSCredential>] [<CommonParameters>]
```

### byProject
```
Get-JiraVersion [-Project] <String[]> [-Name <String[]>] [-Credential <PSCredential>] [<CommonParameters>]
```

### byInputProject
```
Get-JiraVersion [-InputProject] <Object> [-Name <String[]>] [-Credential <PSCredential>] [<CommonParameters>]
```

## DESCRIPTION
{{Fill in the Description}}

## EXAMPLES

### Example 1
```powershell
PS C:\> {{ Add example code here }}
```

{{ Add example description here }}

## PARAMETERS

### -Credential
{{Fill Credential Description}}

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
{{Fill Id Description}}

```yaml
Type: Int32[]
Parameter Sets: byId
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -InputProject
{{Fill InputProject Description}}

```yaml
Type: Object
Parameter Sets: byInputProject
Aliases:

Required: True
Position: 0
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### -InputVersion
{{Fill InputVersion Description}}

```yaml
Type: Object
Parameter Sets: byInputVersion
Aliases:

Required: True
Position: 0
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### -Name
{{Fill Name Description}}

```yaml
Type: String[]
Parameter Sets: byProject, byInputProject
Aliases: Versions

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Project
{{Fill Project Description}}

```yaml
Type: String[]
Parameter Sets: byProject
Aliases: Key

Required: True
Position: 0
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see about_CommonParameters (http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.Object

## OUTPUTS

### System.Object

## NOTES

## RELATED LINKS
