#requires -version 3
[CmdletBinding()]
Param()

# Pester >4.x tests for Svendsen Tech's Merge-Csv function/module.
# Created: 2017-11-18.
# Author: Joakim Borger Svendsen

Import-Module -Name Pester -ErrorAction Stop
# Putting this in the wild...
Remove-Module -Name MergeCsv -ErrorAction Stop
Import-Module -Name MergeCsv -ErrorAction Stop

# Doing this instead, at least for myself, to avoid having to copy files to
# the profile/computer PowerShell modules directory each time...
#Copy-Item -Path ..\MergeCsv.psm1 -Destination $PSScriptRoot
#Move-Item -Path .\MergeCsv.psm1 -Destination "$PSScriptRoot\MergeCsv.ps1" -Force
#. "$PSScriptRoot\MergeCsv.ps1"

Describe "Merge-Csv" {
    It "Merges two simple CSV files / objects correctly" {
        $EmailObjects = @([PSCustomObject] @{
            Username = "John"
            Email = "john@example.com"
        }, [PSCustomObject] @{
            Username = "Jane"
            Email = "jane@example.com"
        })
        $DepartmentObjects = @([PSCustomObject] @{
            Username = "John"
            Department = "HR"
        }, [PSCustomObject] @{
            Username = "Jane"
            Department = "IT"
        })
        (Merge-Csv -InputObject $EmailObjects, $DepartmentObjects -Identity Username |
            Sort-Object Username |
            ConvertTo-Json -Depth 100 -Compress) -eq `
            '[{"Username":"Jane","Email":"jane@example.com","Department":"IT"},{"Username":"John","Email":"john@example.com","Department":"HR"}]' |
            Should -Be $True
    }
}
