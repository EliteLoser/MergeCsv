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

# Doing this instead, at least for myself, to avoid having to copy files to
# the profile/computer PowerShell modules directory each time...
#Copy-Item -Path ..\MergeCsv.psm1 -Destination $PSScriptRoot\MergeCsv.ps1
###Move-Item -Path .\MergeCsv.psm1 -Destination "$PSScriptRoot\MergeCsv.ps1" -Force
#. "$PSScriptRoot\MergeCsv.ps1"

Describe "Merge-Csv" {
    
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
        (Merge-Csv -InputObject $EmailObjects, $DepartmentObjects -Identity Username |
            Sort-Object Username |
            ConvertTo-Json -Depth 100 -Compress) -eq `
            '[{"Username":"Jane","Email":"jane@example.com","Department":"IT"},{"Username":"Janet","Email":"janet@maintexample.com","Department":"Maintenance"},{"Username":"John","Email":"john@example.com","Department":"HR"}]' |
            Should -Be $True
    }

    It "Merges two simple CSV files with three IDs correctly" {
        function InternalTestPathCSV {
            [CmdletBinding()]
            Param([String] $FilePath)
            if (-not (Test-Path -Path "$PSScriptRoot\$FilePath" -PathType Leaf)) {
                if (-not (Test-Path -Path "$PSScriptRoot\template-csvs\$FilePath" -PathType Leaf)) {
                    throw "'$FilePath' isn't in the same directory as the test script or in a subfolder called 'template-csvs'."
                }
                else {
                    "$PSScriptRoot\template-csvs\$FilePath"
                }
            }
            else {
                "$PSScriptRoot\$FilePath"
            }
        }
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

}
