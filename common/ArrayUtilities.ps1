$ErrorActionPreference = "Stop"
Set-StrictMode -Version "2.0"

function Exclude-Items
{
    param(
        [Parameter(Mandatory=$true)]
        [array]$from,

        [Parameter(Mandatory=$true)]
        [array]$items
    )

    return compare -ReferenceObject $from -DifferenceObject $items `
        | where { $_.SideIndicator -eq '<=' } `
        | % { $_.InputObject }
}