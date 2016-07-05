param
(
    [Parameter(Mandatory=$true)]
    [string]$projectFilePath,

    [Parameter(Mandatory=$true)]
    [string]$outputPathPatternOfReferencedProjects
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

. $PSScriptRoot\common\FileUtilities.ps1
. $PSScriptRoot\common\ProjectAnalysis.ps1

function Get-ProjectOutputPaths
{
     param(
        [Parameter(Mandatory=$true)]
        [array]$projectPaths,

        [Parameter(Mandatory=$true)]
        [string]$outputPathPatternOfReferencedProjects,

        [Parameter(Mandatory=$true)]
        [string]$fallbackPathRoot
    )

    return $projectPaths `
        | % { 
            
            $projectName = Split-Path -Leaf $_
            $projectDirectory = Split-Path -Parent $_
            
            $searchLocation = $outputPathPatternOfReferencedProjects -replace "\[projectName\]", $projectName 
            $searchLocation = $outputPathPatternOfReferencedProjects -replace "\[projectDir\]", $projectDirectory

            return (Ensure-PathIsRooted -pathToTest $searchLocation -fallbackPathRoot $fallbackPathRoot)
        } `
        | select -Unique
}

function Build-SearchLocationsList 
{
    param(
        [Parameter(Mandatory=$true)]
        [string]$projectFilePath,

        [Parameter(Mandatory=$true)]
        [string]$outputPathPatternOfReferencedProjects
    )

    $projectDependencies = Get-ProjectDependencies -projectFilePath $projectFilePath -recursive $true

    return @($projectDependencies.ReferencedStaticAssemblyPaths `
            | % { Split-Path -Parent $_ } `
            | select -Unique) `
        + @(Get-ProjectOutputPaths `
            -projectPaths $projectDependencies.ReferencedProjectPaths `
            -outputPathPatternOfReferencedProjects $outputPathPatternOfReferencedProjects `
            -fallbackPathRoot (Split-Path -Parent $projectFilePath)) `
        | select -Unique
}

function Search-FilesAtLocations
{
    param
    (
        [Parameter(Mandatory=$true)]
        [array]$filesToSearch,

        [Parameter(Mandatory=$true)]
        [array]$searchDirectories
    )

    return $filesToSearch `
        | % {
                $fileToLocationMapping = {}
                $fileToLocationMapping | Add-Member FileName $_
                $fileToLocationMapping | Add-Member Path $null

                $searchDirectories | % {
                    $proposedFilePath = Join-Path $_ $fileToLocationMapping.FileName

                    if (Test-Path $proposedFilePath) {
                        $fileToLocationMapping.Path = $proposedFilePath
                    }
                }

                return $fileToLocationMapping
            }
}

function Validate-AllFilesHaveLocationMapping
{
    param
    (
        [Parameter(Mandatory=$true)]
        [array]$fileToLocationMappings
    )

    return $fileToLocationMappings `
        | % {
                if ($_.Path -eq $null) {
                    return $_.FileName
                }

                return $null
            } `
        | where { $_ -ne $null }
}

Ensure-ExistsOrThrow `
    -fileOrDirectoryPath $projectFilePath `
    -errorMessage "There is no project file at $projectFilePath"

$projectDirectory = Split-Path -Parent $projectFilePath

$embeddedAssembliesDirectory = "${projectDirectory}\Embedded"

if (Test-Path $embeddedAssembliesDirectory) {
    Clear-Directory -directoryPath $embeddedAssembliesDirectory
}
else {
    New-Item -type directory $embeddedAssembliesDirectory | Out-Null
}

$embeddedAssemblies = @(Get-EmbeddedAssemblies -projectFilePath $projectFilePath)

$searchLocations = @(Build-SearchLocationsList -projectFilePath $projectFilePath -outputPathPatternOfReferencedProjects $outputPathPatternOfReferencedProjects)

$embeddedAssemblyToLocationMappings = @(Search-FilesAtLocations -filesToSearch $embeddedAssemblies -searchDirectories $searchLocations)

$notFoundAssemblies = @(Validate-AllFilesHaveLocationMapping -fileToLocationMappings $embeddedAssemblyToLocationMappings)

if ($notFoundAssemblies.Length -gt 0)
{
    Write-Error `
    (
        "The following assemblies are not found at the specified search locations:`n" + `
        ($notFoundAssemblies -join "`n") + "`n`n" + `
        "Search locations are:`n" + `
        ($searchLocations -join "`n") + "`n" + `
        "Ensure that corresponding projects are specified explicitly in the build definitions file"
    )
}

$embeddedAssemblyPaths = @($embeddedAssemblyToLocationMappings | select -ExpandProperty "Path")

$embeddedAssemblyPaths | % { Copy-Item $_ $embeddedAssembliesDirectory }