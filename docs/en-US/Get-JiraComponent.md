---
external help file: JiraPS-help.xml
Module Name: JiraPS
online version:
schema: 2.0.0
---

# Get-JiraComponent

## SYNOPSIS
{{Fill in the Synopsis}}

## SYNTAX

### ByID (Default)
```
Get-JiraComponent [-ComponentId] <Int32[]> [-Credential <PSCredential>] [<CommonParameters>]
```

### ByProject
```
Get-JiraComponent [-Project] <Object[]> [-Credential <PSCredential>] [<CommonParameters>]
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

### -ComponentId
{{Fill ComponentId Description}}

```yaml
Type: Int32[]
Parameter Sets: ByID
Aliases: Id

Required: True
Position: 0
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

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

### -Project
{{Fill Project Description}}

```yaml
Type: Object[]
Parameter Sets: ByProject
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

### System.Object[]

## OUTPUTS

### System.Object

## NOTES

## RELATED LINKS
