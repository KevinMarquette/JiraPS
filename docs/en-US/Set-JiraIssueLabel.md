---
external help file: JiraPS-help.xml
Module Name: JiraPS
online version:
schema: 2.0.0
---

# Set-JiraIssueLabel

## SYNOPSIS
{{Fill in the Synopsis}}

## SYNTAX

### ReplaceLabels (Default)
```
Set-JiraIssueLabel [-Issue] <Object[]> -Set <String[]> [-Credential <PSCredential>] [-PassThru] [-WhatIf]
 [-Confirm] [<CommonParameters>]
```

### ModifyLabels
```
Set-JiraIssueLabel [-Issue] <Object[]> [-Add <String[]>] [-Remove <String[]>] [-Credential <PSCredential>]
 [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### ClearLabels
```
Set-JiraIssueLabel [-Issue] <Object[]> [-Clear] [-Credential <PSCredential>] [-PassThru] [-WhatIf] [-Confirm]
 [<CommonParameters>]
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

### -Add
{{Fill Add Description}}

```yaml
Type: String[]
Parameter Sets: ModifyLabels
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Clear
{{Fill Clear Description}}

```yaml
Type: SwitchParameter
Parameter Sets: ClearLabels
Aliases:

Required: True
Position: Named
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

### -Issue
{{Fill Issue Description}}

```yaml
Type: Object[]
Parameter Sets: (All)
Aliases: Key

Required: True
Position: 0
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### -PassThru
{{Fill PassThru Description}}

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Remove
{{Fill Remove Description}}

```yaml
Type: String[]
Parameter Sets: ModifyLabels
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Set
{{Fill Set Description}}

```yaml
Type: String[]
Parameter Sets: ReplaceLabels
Aliases: Label, Replace

Required: True
Position: Named
Default value: None
Accept pipeline input: False
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

### System.Object[]

## OUTPUTS

### System.Object

## NOTES

## RELATED LINKS
