#requires -version 3
[CmdletBinding()]
Param()
# Pester >4.x tests for Svendsen Tech's Merge-Csv function/module.
# Created: 2017-11-18.
# Author: Joakim Borger Svendsen

Import-Module -Name Pester -ErrorAction Stop
# Putting this in the wild...
Remove-Module -Name MergeCsv -ErrorAction SilentlyContinue
Import-Module -Name MergeCsv -ErrorAction Stop
#$MyScriptRoot = Split-Path -Path $MyInvocation.MyCommand.Path -Parent

# Doing this instead, at least for myself, to avoid having to copy files to
# the profile/computer PowerShell modules directory each time...
#Copy-Item -Path ..\MergeCsv.psm1 -Destination $PSScriptRoot\MergeCsv.ps1
###Move-Item -Path .\MergeCsv.psm1 -Destination "$PSScriptRoot\MergeCsv.ps1" -Force
#. "$PSScriptRoot\MergeCsv.ps1"

Describe "Merge-Csv" {
    
    function InternalTestPathCSV {
        [CmdletBinding()]
        Param([String] $FilePath)
        if (-not (Test-Path -Path "$PSScriptRoot\template-csvs\$FilePath" -PathType Leaf)) {
            if (-not (Test-Path -Path "$PSScriptRoot\$FilePath" -PathType Leaf)) {
                throw "'$FilePath' isn't in the same directory as the test script or in a subfolder called 'template-csvs'."
            }
            else {
                "$PSScriptRoot\$FilePath"
            }
        }
        else {
            "$PSScriptRoot\template-csvs\$FilePath"
        }
    }
    
    It "Merges two simple objects with three IDs correctly" {
        
        $EmailObjects = @([PSCustomObject] @{
            Username = "John"
            Email = "john@example.com"
        }, [PSCustomObject] @{
            Username = "Jane"
            Email = "jane@example.com"
        }, [PSCustomObject] @{
            Username = "Janet"
            Email = "janet@maintexample.com"
        })
        $DepartmentObjects = @([PSCustomObject] @{
            Username = "John"
            Department = "HR"
        }, [PSCustomObject] @{
            Username = "Jane"
            Department = "IT"
        }, [PSCustomObject] @{
            Username = "Janet"
            Department = "Maintenance"
        })
        ((Merge-Csv -InputObject $EmailObjects, $DepartmentObjects -Identity Username |
            Sort-Object Username |
            ConvertTo-Json -Depth 100 -Compress) 3> $null) -eq `
            '[{"Username":"Jane","Email":"jane@example.com","Department":"IT"},{"Username":"Janet","Email":"janet@maintexample.com","Department":"Maintenance"},{"Username":"John","Email":"john@example.com","Department":"HR"}]' |
            Should -Be $True
    
    }

    It "Merges two simple CSV files with three IDs correctly" {
        
        $FirstPath, $SecondPath = "simplecsv1.csv", "simplecsv2.csv" |
            ForEach-Object {
                InternalTestPathCSV -FilePath $_
            }
        Write-Verbose -Message "First path: $FirstPath. Second path: $SecondPath." #-Verbose
        (Merge-Csv -Path $FirstPath, $SecondPath -Identity Username |
            Sort-Object Username |
            ConvertTo-Json -Depth 100 -Compress) -eq `
            '[{"Username":"Jane","Email":"jane@example.com","Department":"IT"},{"Username":"Janet","Email":"janet@maintexample.com","Department":"Maintenance"},{"Username":"John","Email":"john@example.com","Department":"HR"}]' |
            Should -Be $True
    
    }

    It "Merges three somewhat complex CSV files with two IDs properly" {
        
        $FirstPath, $SecondPath, $ThirdPath = "csv1.csv", "csv2.csv", "csv3.csv" |
            ForEach-Object {
                InternalTestPathCSV -FilePath $_
            }
        Write-Verbose ("`n" + ($FirstPath, $SecondPath, $ThirdPath -join "`n")) #-Verbose
        ((Merge-Csv -Path $FirstPath, $SecondPath, $ThirdPath -Identity ComputerName, Uh -WarningVariable Warnings |
            Sort-Object -Property ComputerName, Uh |
            ConvertTo-Json -Depth 100 -Compress) 3> $null) -eq `
        '[{"ComputerName":"ServerA","Uh":"UhA","OSFamily":"Windows","Env":"Production","PSVer":"5.1","OrderFile3":"1"},{"ComputerName":"ServerB","Uh":"UhB","OSFamily":"Windows","Env":"Test","PSVer":"5.1","OrderFile3":"5"}]' |
            Should -Be $True
        $Warnings.Count | Should -Be 9

    }

    It "Merges three somewhat complex CSV files with two IDs properly, with -AllowDuplicates" {
        
        $FirstPath, $SecondPath, $ThirdPath = "csv1.csv", "csv2.csv", "csv3.csv" |
            ForEach-Object {
                InternalTestPathCSV -FilePath $_
            }
        ((Merge-Csv -Path $FirstPath, $SecondPath, $ThirdPath -Identity ComputerName, Uh -AllowDuplicates -WarningVariable Warnings |
            Sort-Object -Property ComputerName, Uh, OrderFile3 |
            ConvertTo-Json -Depth 100 -Compress) 3> $null) -eq `
        '[{"ComputerName":"ServerA","Uh":"UhA","OSFamily":"Windows","Env":"Production","PSVer":"5.1","OrderFile3":"1"},{"ComputerName":"ServerA","Uh":"UhA","OSFamily":"Linux","Env":"Test","PSVer":"6.0","OrderFile3":"2"},{"ComputerName":"ServerA","Uh":"UhA","OSFamily":null,"Env":"Production","PSVer":"3.0","OrderFile3":"3"},{"ComputerName":"ServerA","Uh":"UhA","OSFamily":null,"Env":null,"PSVer":null,"OrderFile3":"4"},{"ComputerName":"ServerB","Uh":"UhB","OSFamily":"Windows","Env":"Test","PSVer":"5.1","OrderFile3":"5"},{"ComputerName":"ServerB","Uh":"UhB","OSFamily":"Linux","Env":"Legacy","PSVer":"6.0","OrderFile3":"6"}]' |
            Should -Be $True
        $Warnings.Count | Should -Be 0

    }
    
    It "Warns about duplicates" {
        
        $Object1 = @([PSCustomObject] @{
            Username = "Repeated"
            foo = "bar"
        }, [PSCustomObject] @{
            Username = "Repeated"
            foo = "barf"
        })
        $Object2 = [PSCustomObject] @{
            Username = "Repeated"
            bar = "foo"
        }
        
        (Merge-Csv -InputObject $Object1, $Object2 -Identity Username -WarningVariable Warnings) 3> $null | Out-Null
        $Warnings.Message |
            Should -Match "Duplicate identifying \(shared column\(s\) ID\) entry found in CSV data/file 1: Repeated"
        # Check in reverse order.
        (Merge-Csv -InputObject $Object2, $Object1 -Identity Username -WarningVariable Warnings) 3> $null | Out-Null
        $Warnings.Message |
            Should -Match "Duplicate identifying \(shared column\(s\) ID\) entry found in CSV data/file 2: Repeated"
        
    }

    It "Warns about duplicates with two ID fields" {
        
        $Object1 = @([PSCustomObject] @{
            Username = "Repeated"
            ID2 = "a"
            foo = "bar"
        }, [PSCustomObject] @{
            Username = "Repeated"
            ID2 = "a"
            foo = "barf"
        })
        $Object2 = [PSCustomObject] @{
            Username = "Repeated"
            ID2 = "a"
            bar = "foo"
        }
        
        (Merge-Csv -InputObject $Object1, $Object2 -Identity Username, ID2 -WarningVariable Warnings) 3> $null | Out-Null
        $Warnings.Message |
            Should -Match "Duplicate identifying \(shared column\(s\) ID\) entry found in CSV data/file 1: Repeated, a"
        
        # Check in reverse order.
        (Merge-Csv -InputObject $Object2, $Object1 -Identity Username, ID2 -WarningVariable Warnings) 3> $null | Out-Null
        $Warnings.Message |
            Should -Match "Duplicate identifying \(shared column\(s\) ID\) entry found in CSV data/file 2: Repeated, a"
        
    }

    It "Warns about duplicates with two ID fields and >2 objects" {
        
        $Object1 = @([PSCustomObject] @{
            Username = "Repeated"
            ID2 = "a"
            foo = "bar"
        }, [PSCustomObject] @{
            Username = "Repeated"
            ID2 = "a"
            foo = "barf"
        })
        $Object2 = [PSCustomObject] @{
            Username = "Repeated"
            ID2 = "a"
            bar = "foo"
        }
        $Object3 = [PSCustomObject] @{
            Username = "Repeated"
            ID2 = "a"
            baz = "boo"
        }
        
        # Check that position 3 is reported correctly.
        (Merge-Csv -InputObject $Object3, $Object2, $Object1 -Identity Username, ID2 -WarningVariable Warnings) 3> $null | Out-Null
        $Warnings.Message |
            Should -Match "Duplicate identifying \(shared column\(s\) ID\) entry found in CSV data/file 3: Repeated, a"
        
        # Check as second.
        (Merge-Csv -InputObject $Object2, $Object1, $Object3 -Identity Username, ID2 -WarningVariable Warnings) 3> $null | Out-Null
        $Warnings.Message |
            Should -Match "Duplicate identifying \(shared column\(s\) ID\) entry found in CSV data/file 2: Repeated, a"
        
        # Check as first.
        (Merge-Csv -InputObject $Object1, $Object2, $Object3 -Identity Username, ID2 -WarningVariable Warnings) 3> $null | Out-Null
        $Warnings.Message |
            Should -Match "Duplicate identifying \(shared column\(s\) ID\) entry found in CSV data/file 1: Repeated, a"
        
    }

    It "Warns about a missing ID property in one or more of three objects" {
        
        $Object1 = @([PSCustomObject] @{
            Username = "Repeated"
            foo = "bar"
        }, [PSCustomObject] @{
            Username = "MissingInTheOther"
            foo = "bar2"
        })
        $Object2 = [PSCustomObject] @{
            Username = "Repeated"
            bar = "foo"
        }
        $Object3 = [PSCustomObject] @{
            Username = "Repeated"
            baz = "boo"
        }
        
        # Check position 1.
        (Merge-Csv -InputObject $Object1, $Object2, $Object3 -Identity Username -WarningVariable Warnings) 3> $null | Out-Null
        $Warnings.Message |
            Should -Match "Identifying column entry '$($Object1[1].Username
                )' was not found in all CSV data objects/files. Found in object/file no.: 1"
        
        # Check position 2.
        (Merge-Csv -InputObject $Object2, $Object1, $Object3 -Identity Username -WarningVariable Warnings) 3> $null | Out-Null
        $Warnings.Message |
            Should -Match "Identifying column entry '$($Object1[1].Username
                )' was not found in all CSV data objects/files. Found in object/file no.: 2"
        
        # Check position 3.
        (Merge-Csv -InputObject $Object3, $Object2, $Object1 -Identity Username -WarningVariable Warnings) 3> $null | Out-Null
        $Warnings.Message |
            Should -Match "Identifying column entry '$($Object1[1].Username
                )' was not found in all CSV data objects/files. Found in object/file no.: 3"
        
        # Check two scenarios where
        $Object2 = @([PSCustomObject] @{
            Username = "Repeated"
            bar = "foo"
        }, [PSCustomObject] @{
            Username = "MissingInTheOther"
            bar = "foo2"
        })
        
        # Check when it's missing in position 1.
        (Merge-Csv -InputObject $Object3, $Object2, $Object1 -Identity Username -WarningVariable Warnings) 3> $null | Out-Null
        $Warnings.Message |
            Should -Match "Identifying column entry '$($Object2[1].Username
                )' was not found in all CSV data objects/files. Found in object/file no.: 2, 3"
        
        # Check when it's missing in position 2.
        (Merge-Csv -InputObject $Object2, $Object3, $Object1 -Identity Username -WarningVariable Warnings) 3> $null | Out-Null
        $Warnings.Message |
            Should -Match "Identifying column entry '$($Object1[1].Username
                )' was not found in all CSV data objects/files. Found in object/file no.: 1, 3"
        
        # Check when it's missing in position 3.
        (Merge-Csv -InputObject $Object1, $Object2, $Object3 -Identity Username -WarningVariable Warnings) 3> $null | Out-Null
        $Warnings.Message |
            Should -Match "Identifying column entry '$($Object1[1].Username
                )' was not found in all CSV data objects/files. Found in object/file no.: 1, 2"
        
    }
    
    It "Warns about a missing, combined ID property (two properties) in one or more of three objects" {
        
        $Object1 = @([PSCustomObject] @{
            Username = "Repeated"
            ID2 = "a"
            foo = "bar"
        }, [PSCustomObject] @{
            Username = "MissingInTheOther"
            ID2 = "m"
            foo = "bar2"
        })
        $Object2 = [PSCustomObject] @{
            Username = "Repeated"
            ID2 = "a"
            bar = "foo"
        }
        $Object3 = [PSCustomObject] @{
            Username = "Repeated"
            ID2 = "a"
            baz = "boo"
        }
        
        # Check position 1.
        (Merge-Csv -InputObject $Object1, $Object2, $Object3 -Identity Username, ID2 -WarningVariable Warnings) 3> $null | Out-Null
        $Warnings.Message |
            Should -Match "Identifying column entry '$(($Object1[1].Username,
                $Object1[1].ID2) -join ', ')' was not found in all CSV data objects/files. Found in object/file no.: 1"
        
        # Check position 2.
        (Merge-Csv -InputObject $Object2, $Object1, $Object3 -Identity Username, ID2 -WarningVariable Warnings) 3> $null | Out-Null
        $Warnings.Message |
            Should -Match "Identifying column entry '$(($Object1[1].Username,
                $Object1[1].ID2) -join ', ')' was not found in all CSV data objects/files. Found in object/file no.: 2"
        
        # Check position 3.
        (Merge-Csv -InputObject $Object3, $Object2, $Object1 -Identity Username, ID2 -WarningVariable Warnings) 3> $null | Out-Null
        $Warnings.Message |
            Should -Match "Identifying column entry '$(($Object1[1].Username,
                $Object1[1].ID2) -join ', ')' was not found in all CSV data objects/files. Found in object/file no.: 3"
        
        $Object2 = @([PSCustomObject] @{
            Username = "Repeated"
            ID2 = "a"
            food = "bar33"
        }, [PSCustomObject] @{
            Username = "MissingInTheOther"
            ID2 = "m"
            food = "bar3"
        })
        
        # Check when it's missing in position 1.
        (Merge-Csv -InputObject $Object3, $Object2, $Object1 -Identity Username, ID2 -WarningVariable Warnings) 3> $null | Out-Null
        $Warnings.Message |
            Should -Match "Identifying column entry '$(($Object1[1].Username,
                $Object1[1].ID2) -join ', ')' was not found in all CSV data objects/files. Found in object/file no.: 2, 3"
        
        # Check when it's missing in position 2.
        (Merge-Csv -InputObject $Object2, $Object3, $Object1 -Identity Username, ID2 -WarningVariable Warnings) 3> $null | Out-Null
        $Warnings.Message |
            Should -Match "Identifying column entry '$(($Object1[1].Username,
                $Object1[1].ID2) -join ', ')' was not found in all CSV data objects/files. Found in object/file no.: 1, 3"
        
        # Check when it's missing in position 3.
        (Merge-Csv -InputObject $Object1, $Object2, $Object3 -Identity Username, ID2 -WarningVariable Warnings) 3> $null | Out-Null
        $Warnings.Message |
            Should -Match "Identifying column entry '$(($Object1[1].Username,
                $Object1[1].ID2) -join ', ')' was not found in all CSV data objects/files. Found in object/file no.: 1, 2"
        
    }
    
}
