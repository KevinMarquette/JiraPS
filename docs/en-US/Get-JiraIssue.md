---
external help file: JiraPS-help.xml
Module Name: JiraPS
online version:
schema: 2.0.0
---

# Get-JiraIssue

## SYNOPSIS
{{Fill in the Synopsis}}

## SYNTAX

### ByIssueKey (Default)
```
Get-JiraIssue [-Key] <String[]> [-Credential <PSCredential>] [<CommonParameters>]
```

### ByInputObject
```
Get-JiraIssue [-InputObject] <Object[]> [-Credential <PSCredential>] [<CommonParameters>]
```

### ByJQL
```
Get-JiraIssue -Query <String> [-StartIndex <Int32>] [-MaxResults <Int32>] [-PageSize <Int32>]
 [-Credential <PSCredential>] [<CommonParameters>]
```

### ByFilter
```
Get-JiraIssue -Filter <Object> [-StartIndex <Int32>] [-MaxResults <Int32>] [-PageSize <Int32>]
 [-Credential <PSCredential>] [<CommonParameters>]
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

### -Filter
{{Fill Filter Description}}

```yaml
Type: Object
Parameter Sets: ByFilter
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -InputObject
{{Fill InputObject Description}}

```yaml
Type: Object[]
Parameter Sets: ByInputObject
Aliases:

Required: True
Position: 0
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Key
{{Fill Key Description}}

```yaml
Type: String[]
Parameter Sets: ByIssueKey
Aliases:

Required: True
Position: 0
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -MaxResults
{{Fill MaxResults Description}}

```yaml
Type: Int32
Parameter Sets: ByJQL, ByFilter
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -PageSize
{{Fill PageSize Description}}

```yaml
Type: Int32
Parameter Sets: ByJQL, ByFilter
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Query
{{Fill Query Description}}

```yaml
Type: String
Parameter Sets: ByJQL
Aliases: JQL

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -StartIndex
{{Fill StartIndex Description}}

```yaml
Type: Int32
Parameter Sets: ByJQL, ByFilter
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see about_CommonParameters (http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None

## OUTPUTS

### System.Object

## NOTES

## RELATED LINKS
