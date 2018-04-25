---
external help file: JiraPS-help.xml
Module Name: JiraPS
online version:
schema: 2.0.0
---

# ConvertFrom-Json2

## SYNOPSIS
Function to overwrite or be used instead of the native \`ConvertFrom-Json\` of PowerShell

## SYNTAX

```
ConvertFrom-Json2 [-InputObject] <Object[]> [[-MaxJsonLength] <Int32>] [<CommonParameters>]
```

## DESCRIPTION
ConvertFrom-Json implementation does not allow for overriding JSON maxlength.
The default limit is easy to exceed with large issue lists.

## EXAMPLES

### Example 1
```powershell
PS C:\> {{ Add example code here }}
```

{{ Add example description here }}

## PARAMETERS

### -InputObject
{{Fill InputObject Description}}

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

### -MaxJsonLength
{{Fill MaxJsonLength Description}}

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: 2147483647
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see about_CommonParameters (http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS
