function Ensure-PathIsRooted
{
    param
    (
        [Parameter(Mandatory=$true)]
        [string]$pathToTest,

        [Parameter(Mandatory=$true)]
        [string]$fallbackPathRoot
    )

    if ([IO.Path]::IsPathRooted($pathToTest)) {
        return $pathToTest
    }
    else {
        return "$fallbackPathRoot\$pathToTest"
    }
}

function Ensure-ExistsOrThrow
{
    param
    (
        [Parameter(Mandatory=$true)]
        [string]$fileOrDirectoryPath,

        [Parameter(Mandatory=$true)]
        [string]$errorMessage
    )

    if (-Not (Test-Path $fileOrDirectoryPath)) {
        Write-Error $errorMessage
    }
}

function Ensure-PathIsResolved
{
    param(
        [Parameter(Mandatory=$true)]
        $path
    )

    return (Resolve-Path -Path $path).Path
}

function Clear-Directory
{
    param(
        [Parameter(Mandatory=$true)]
        [string]$directoryPath
    )

    Get-ChildItem $directoryPath `
        | % { Set-ItemProperty "${directoryPath}\$_" -name IsReadOnly -value $false }

    Remove-Item "${directoryPath}\*"
}

function Is-AssemblyFile
{
    param(
        [Parameter(Mandatory=$true)]
        [string]$assemblyFileName
    )

    return $assemblyFileName.EndsWith(".dll") -or $assemblyFileName.EndsWith(".exe")
}

function Get-ChildFilePaths
{
    param(
        [parameter(mandatory=$true)]
        [string]$directoryPath
    )

    Get-ChildItem $directoryPath -File `
        | % { $_.FullName }
}

function Select-SinglePathByFileName
{
    param(
        [parameter(mandatory=$true)]
        [array]$fromPaths,

        [parameter(mandatory=$true)]
        [string]$fileName
    )

    $fromPaths `
        | where { (Split-Path -Leaf $_ ) -eq $fileName } `
        | select -first 1
}

function Trim-AssemblyExtension
{
    param(
        [Parameter(Mandatory=$true)]
        [string]$assemblyFileName
    )

    $trimmedAssemblyName = $assemblyFileName

    $trimmedAssemblyName = $trimmedAssemblyName -replace "\.dll", ""
    $trimmedAssemblyName = $trimmedAssemblyName -replace "\.exe", ""

    return $trimmedAssemblyName
}