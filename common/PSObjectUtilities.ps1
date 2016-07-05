$ErrorActionPreference = "Stop"
Set-StrictMode -Version "2.0"

function Has-Property
{
    param(
        [parameter(mandatory=$true)]
        $psObject,

        [parameter(mandatory=$true)]
        $propertyName
    )

    [bool]($psObject.PSObject.Properties.name -match $propertyName)
}
