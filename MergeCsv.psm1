#requires -version 3

 
<#
.SYNOPSIS
Merges an arbitrary amount of CSV files or PowerShell objects based on an ID column or
several combined ID columns. Works on custom PowerShell objects with the InputObject parameter.

.DESCRIPTION
Slapping parentheses around Import-Csv like, say, "-InputObject (ipcsv csvfile.csv), $objectHere"
is good for a mix of objects and CSV files.

PowerShell version 3 or higher is needed.

Copyright Joakim Borger Svendsen (C) 2014-2017
All rights reserved.
Svendsen Tech

MIT license.

Online documentation:
http://www.powershelladmin.com/wiki/Merge_CSV_files_or_PSObjects_in_PowerShell

GitHub:
https://github.com/EliteLoser/MergeCsv/

The PowerShell Gallery:
https://www.powershellgallery.com/packages/MergeCsv/

.PARAMETER Identity
Shared ID property/header (multiple supported).

.PARAMETER Path
CSV files to process.

.PARAMETER InputObject
Custom PowerShell objects to process.

.PARAMETER Delimiter
Optional delimiter that's used if you pass file paths (default is a comma).

.PARAMETER Separator
Optional multi-ID column string separator (default "#Merge-Csv-Separator#").

.PARAMETER AllowDuplicates
Allow and aggregate duplicate entries (IDs) in the order they occur.

.PARAMETER IncludeAliasProperty
Include alias properties in addition to note properties.

.EXAMPLE
ipcsv users.csv | ft -AutoSize

Username Department
-------- ----------
John     IT        
Jane     HR        

PS C:\> ipcsv user-mail.csv | ft -AutoSize

Username Email           
-------- -----           
John     john@example.com
Jane     jane@example.com

PS C:\> Merge-Csv -Path users.csv, user-mail.csv -Id Username | Export-Csv -enc UTF8 merged.csv

PS C:\> ipcsv .\merged.csv | ft -AutoSize

Username Department Email           
-------- ---------- -----           
John     IT         john@example.com
Jane     HR         jane@example.com

.EXAMPLE
Merge-Csv -In (ipcsv .\csv1.csv), (ipcsv csv2.csv), (ipcsv csv3.csv) -Id Username | Sort-Object username | ft -AutoSize

Merging three files.

WARNING: Duplicate identifying (shared column(s) ID) entry found in CSV data/file 0: user42
WARNING: Identifying column entry 'firstOnly' was not found in all CSV data objects/files. Found in object/file no.: 1
WARNING: Identifying column entry '2only' was not found in all CSV data objects/files. Found in object/file no.: 2
WARNING: Identifying column entry 'user2and3only' was not found in all CSV data objects/files. Found in object/file no.: 2, 3

Username      File1A      File1B      TestID File2A  File2B  TestX      File3  
--------      ------      ------      ------ ------  ------  -----      -----  
2only                                        a       b       c                 
firstOnly     firstOnlyA1 firstOnlyB1 foo                                      
user1         1A1         1B1         same   1A3     2A3     same       same   
user2         2A1         2B1         diff2  2A3     2B3     diff2_2    testC2 
user2and3only                                2and3A2 2and3B2 test2and3X testID 
user3         3A1         3B1         same   3A3     3B3     same       same   
user42        42A1        42B1        same42 testA42 testB42 testX42    testC42

.EXAMPLE
Merge-Csv -Path csvmerge1.csv, csvmerge2.csv, csvmerge3.csv -Id Username, TestID | Sort-Object username | ft -a

Two shared/ID column, three files.

WARNING: Duplicate identifying (shared column(s) ID) entry found in CSV data/file 1: user42, same42
WARNING: Identifying column entry 'user2, diff2' was not found in all CSV data objects/files. Found in object/file no.: 1
WARNING: Identifying column entry 'user2and3only, testID' was not found in all CSV data objects/files. Found in object/file no.: 3
WARNING: Identifying column entry 'user2, testC2' was not found in all CSV data objects/files. Found in object/file no.: 3
WARNING: Identifying column entry '2only, c' was not found in all CSV data objects/files. Found in object/file no.: 2
WARNING: Identifying column entry 'user2and3only, test2and3X' was not found in all CSV data objects/files. Found in object/file no.: 2
WARNING: Identifying column entry 'user2, diff2_2' was not found in all CSV data objects/files. Found in object/file no.: 2
WARNING: Identifying column entry 'firstOnly, foo' was not found in all CSV data objects/files. Found in object/file no.: 1

Username      TestID     File1A      File1B      File2A  File2B 
--------      ------     ------      ------      ------  ------ 
2only         c                                  a       b      
firstOnly     foo        firstOnlyA1 firstOnlyB1                
user1         same       1A1         1B1         1A3     2A3    
user2         diff2      2A1         2B1                        
user2         diff2_2                            2A3     2B3    
user2         testC2                                            
user2and3only testID                                            
user2and3only test2and3X                         2and3A2 2and3B2
user3         same       3A1         3B1         3A3     3B3    
user42        same42     42A1        42B1        testA42 testB42

.EXAMPLE
Merge-Csv -Path csv1.csv, csv2.csv, csv3.csv -Id ID -AllowDuplicates | ft -AutoSize

ID       1Title1 1Title2 1Title3 2Title1 2Title2 3Title1  
--       ------- ------- ------- ------- ------- -------  
FooBar   x       y       z       blorp   dongs   first3   
FooBar                           xxx     yyy     second3  
FooBar                                           third3   
Svendsen a       b       c       e       f       SvenData3
Svendsen aa      bb      cc      ee      ff
Svendsen aaa                     eee     fff
#>
function Merge-Csv {
    [CmdletBinding(
        DefaultParameterSetName='Files'
    )]
    param(
        # Shared ID column(s)/header(s).
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String[]] $Identity,
        
        # CSV files to process.
        [Parameter(ParameterSetName='Files',Mandatory=$true)]
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        [String[]] $Path,
        
        # Custom PowerShell objects to process.
        [Parameter(ParameterSetName='Objects',Mandatory=$true)]
        [PSObject[]] $InputObject,
        
        # Optional delimiter that's used if you pass file paths (default is a comma).
        [Parameter(ParameterSetName='Files')]
        [String] $Delimiter = ',',

        # Optional multi-ID column string separator (default "#Merge-Csv-Separator#").
        [String] $Separator = '#Merge-Csv-Separator#',
        
        # Allow duplicate entries (IDs).
        [Switch] $AllowDuplicates,
        
        # Include alias properties.
        [Switch] $IncludeAliasProperty)
    # v1.4 as a module - 2016-10-28 - adding module format prerequisites, cleaning up redundant code
    # v1.4 - 2016-09-16 - Added support for handling duplicate IDs.
    # v1.5. Forgot to make a note here, see wiki.
    # v1.6 - Allowing duplicates, see wiki.
    # v1.7 - 2017-09-13 - Adding -IncludeAliasProperty parameter.
    #                     Non-default to not break old stuff people might have.
    #                     Id parameter changed to full form: Identity.
    # v1.7.0.1 - 2017-09-14 - Empty strings instead of bullshit objects. wtf was I thinking.
    #      Now I have to decide if I manipulate the IDs, possibly "Header1: Value1. Header2: Value2."?
    #      with the title as "Header1. Header2." But periods aren't unique, so I don't know what else
    #      to do right now than keep the silly, presumed unique separator string.
    # v1.7.0.2 - 2017-09-14 - Found a good way to handle multiple IDs with regards to the
    #      presentation aspect! So clever it almost hurts - that's how it feels now anyway.
    [String[]] $PropertyTypes = @()
    if ($IncludeAliasProperty) {
        $PropertyTypes = @("NoteProperty", "AliasProperty")
    }
    else {
        $PropertyTypes = @("NoteProperty")
    }
    [PSObject[]] $CsvObjects = @()
    if ($PSCmdlet.ParameterSetName -eq 'Files') {
        $CsvObjects = foreach ($File in $Path) {
            ,@(Import-Csv -Delimiter $Delimiter -Path $File)
        }
    }
    else {
        $CsvObjects = $InputObject
    }
    $Headers = @()
    foreach ($Csv in $CsvObjects) {
        $Headers += , @($Csv | Get-Member -MemberType $PropertyTypes | Select-Object -ExpandProperty Name)
    }
    $Counter = 0
    foreach ($h in $Headers) {
        $Counter++
        foreach ($Column in $Identity) {
            if ($h -notcontains $Column) {
                Write-Error "Headers in object/file $Counter don't include $Column. Exiting."
                return
            }
        }
    }
    $HeadersFlatNoShared = @($Headers | ForEach-Object { $_ } | Where-Object { $Identity -notcontains $_ })
    if ($HeadersFlatNoShared.Count -ne @($HeadersFlatNoShared | Sort-Object -Unique).Count) {
        Write-Error "Some headers are shared. Are you just looking for '@(ipcsv csv1) + @(ipcsv csv2) | Export-Csv ...'?`nTo remove duplicate (between the files to merge) headers from a CSV file, Import-Csv it, pass it to Select-Object, and omit the duplicate header(s)/column(s).`nExiting."
        return
    }
    $SharedColumnHashes = @()
    $SharedColumnCount = $Identity.Count
    $Counter = 0
    foreach ($Csv in $CsvObjects) {
        $SharedColumnHashes += @{}
        $Csv | ForEach-Object {
            $CurrentID = $(for ($i = 0; $i -lt $SharedColumnCount; $i++) {
                $_ | Select-Object -ExpandProperty $Identity[$i] -EA SilentlyContinue
            }) -join $Separator
            if (-not $SharedColumnHashes[$Counter].ContainsKey($CurrentID)) {
                $SharedColumnHashes[$Counter].Add($CurrentID, @($_ | Select-Object -Property $Headers[$Counter]))
            }
            else {
                if ($AllowDuplicates) {
                    $SharedColumnHashes[$Counter].$CurrentID += $_ | Select-Object -Property $Headers[$Counter]
                }
                else {
                    Write-Warning ("Duplicate identifying (shared column(s) ID) entry found in CSV data/file $($Counter+1): " + ($CurrentID -replace [regex]::Escape($Separator), ', '))
                }
            }
        }
        $Counter++
    }
    $Result = @{}
    $NotFound = @{}
    foreach ($Counter in 0..($SharedColumnHashes.Count-1)) {
        foreach ($InnerCounter in (0..($SharedColumnHashes.Count-1) | Where-Object { $_ -ne $Counter })) {
            foreach ($Key in $SharedColumnHashes[$Counter].Keys) {
                Write-Verbose "Key: $Key, Counter: $Counter, InnerCounter: $InnerCounter"
                $Obj = New-Object -TypeName PSObject
                if ($SharedColumnHashes[$InnerCounter].ContainsKey($Key)) {
                    foreach ($Header in $Headers[$InnerCounter] | Where-Object { $Identity -notcontains $_ }) {
                        Add-Member -InputObject $Obj -MemberType NoteProperty -Name $Header -Value ($SharedColumnHashes[$InnerCounter].$Key | Select-Object $Header)
                    }
                }
                else {
                    foreach ($Header in $Headers[$Counter]) {
                        if ($Identity -notcontains $Header) {
                            Add-Member -InputObject $Obj -MemberType NoteProperty -Name $Header -Value ($SharedColumnHashes[$Counter].$Key | Select-Object $Header)
                        }
                    }
                    if (-not $NotFound.ContainsKey($Key)) {
                        $NotFound.Add($Key, @($Counter))
                    }
                    else {
                        $NotFound[$Key] += $Counter
                    }
                }
                if (-not $Result.ContainsKey($Key)) {
                    $Result.$Key = $Obj
                }
                else {
                    foreach ($Property in @($Obj | Get-Member -MemberType $PropertyTypes | Select-Object -ExpandProperty Name)) {
                        if (-not ($Result.$Key | Get-Member -MemberType $PropertyTypes -Name $Property)) {
                            Add-Member -InputObject $Result.$Key -MemberType NoteProperty -Name $Property -Value $Obj.$Property #-EA SilentlyContinue
                        }
                    }
                }
                
            }
        }
    }
    if ($NotFound) {
        foreach ($Key in $NotFound.Keys) {
            Write-Warning "Identifying column entry '$($Key -replace [regex]::Escape($Separator), ', ')' was not found in all CSV data objects/files. Found in object/file no.: $(
                if ($NotFound.$Key) { ($NotFound.$Key | ForEach-Object { ([int]$_)+1 } | Sort-Object -Unique) -join ', '}
                elseif ($CsvObjects.Count -eq 2) { '1' }
                else { 'none' }
                )"
        }
    }
    #$Global:Result = $Result
    $Counter = 0
    [hashtable[]] $SharedHeadersNoDuplicate = $Identity | ForEach-Object {
        @{n="$($Identity[$Counter])";e=[scriptblock]::Create("(`$_.Name -split ([regex]::Escape('$Separator')))[$Counter]")}
        $Counter++
    }
    [hashtable[]] $HeaderPropertiesNoDuplicate = $HeadersFlatNoShared | ForEach-Object {
        @{n=$_.ToString(); e=[scriptblock]::Create("`$_.Value.'$_' | Select -ExpandProperty '$_'")}
    }
    [int] $HeadersFlatNoSharedCount = $HeadersFlatNoShared.Count
    # Return results.
    if (-not $AllowDuplicates) {
        $Result.GetEnumerator() | Select-Object -Property ($SharedHeadersNoDuplicate + $HeaderPropertiesNoDuplicate)
    }
    else {
        $Result.GetEnumerator() | ForEach-Object {
            # Latching on support for duplicate objects. Insanely inefficient.
            # Variable for the count of duplicates we find. Initialize to 1 for each array of PSobjects for each ID.
            $MaxDuplicateCount = 1
            foreach ($Title in $_.Value | Get-Member -MemberType $PropertyTypes | Select-Object -ExpandProperty Name) {
                $Count = @($_.Value.$Title).Count
                # find max count for this instance (if at all higher than 1)
                # duplicates are processed in the order they occur
                if ($MaxDuplicateCount -lt $Count) {
                    $MaxDuplicateCount = $Count
                }
            }
            Write-Verbose "Max duplicate count: $MaxDuplicateCount"
            foreach ($i in 0..($MaxDuplicateCount-1)) {
                # Add ID(s) once to each object.
                $Obj = $null
                $Obj = New-Object -TypeName PSObject
                $IDSplitCounter = 0
                foreach ($TempID in $Identity) {
                    Add-Member -InputObject $Obj -MemberType NoteProperty -Name $TempID -Value @($_.Name -split [Regex]::Escape($Separator))[$IDSplitCounter]
                    ++$IDSplitCounter
                }
                foreach ($NumHeader in 0..($HeadersFlatNoSharedCount-1)) {
                    try {
                        $Value = ($_.Value.($HeadersFlatNoShared[$NumHeader]))[$i] | Select-Object -ExpandProperty $HeadersFlatNoShared[$NumHeader]
                    }
                    catch {
                        Write-Verbose "Caught out of bounds in array."
                        $Value = '' #| Select-Object -Property $HeadersFlatNoShared[$NumHeader]
                    }
                    Add-Member -InputObject $Obj -MemberType NoteProperty -Name $HeadersFlatNoShared[$NumHeader] -Value $Value
                }
                $Obj | Select-Object -Property ($Identity + $HeadersFlatNoShared)
            }
        }
    }
}
#Export-ModuleMember -Function Merge-Csv
