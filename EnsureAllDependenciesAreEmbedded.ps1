param(
    [Parameter(Mandatory=$true)]
    [string]$projectFilePath
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version "2.0"

. $PSScriptRoot\common\FileUtilities.ps1
. $PSScriptRoot\common\ProjectAnalysis.ps1
. $PSScriptRoot\common\ArrayUtilities.ps1

function Create-ErrorMessage
{
    param(
        [Parameter(Mandatory=$true)]
        [array]$notEmbeddedAssemblyNames
    )

@"
The following dependency assemblies are not embedded (consider to include them into the <ItemGroup>..</ItemGroup> node):
"@

    foreach ($assemblyName in $notEmbeddedAssemblyNames)
    {
@"
<EmbeddedResource Include="Embedded\${assemblyName}.dll" />
"@
    }
}

function Get-ProjectDependentAssemblyNames
{
    param(
        [Parameter(Mandatory=$true)]
        [string]$projectFilePath
    )

    $projectDependencies = Get-ProjectDependencies -projectFilePath $projectFilePath -recursive $true 

    $referencedProjectsAssemblyNames = @($projectDependencies.ReferencedProjectPaths `
        | % { Get-OutputAssemblyName -projectFilePath $_ })

    $referencedStaticAssemblyNames = @($projectDependencies.ReferencedStaticAssemblyPaths `
        | % { Trim-AssemblyExtension (Split-Path -Leaf $_) })

    return @($referencedProjectsAssemblyNames + $referencedStaticAssemblyNames) | select -Unique
}

$embeddedAssemblyNames = @(Get-EmbeddedAssemblies -projectFilePath $projectFilePath | % { Trim-AssemblyExtension -assemblyFileName $_})

$projectDependentAssemblyNames = @(Get-ProjectDependentAssemblyNames -projectFilePath $projectFilePath)

$notEmbeddedAssemblies = @(Exclude-Items -from $projectDependentAssemblyNames -items $embeddedAssemblyNames)

if ($notEmbeddedAssemblies.Length -gt 0) {
    $errorMessage = Create-ErrorMessage -notEmbeddedAssemblyNames $notEmbeddedAssemblies | Out-String
    Write-Error $errorMessage
}

$idleEmbeddedDependencies = @(Exclude-Items -from $embeddedAssemblyNames -items $projectDependentAssemblyNames)

if ($idleEmbeddedDependencies.Length -gt 0) {
    Write-Error `
    (
        "The following embedded assemblies are not used and should be removed:`n" + `
        ($idleEmbeddedDependencies -join "`n")
    )
}