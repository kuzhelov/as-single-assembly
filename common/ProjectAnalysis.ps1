$ErrorActionPreference = "Stop"
Set-StrictMode -Version "2.0"

. $PSScriptRoot\FileUtilities.ps1
. $PSScriptRoot\PSObjectUtilities.ps1
. $PSScriptRoot\Filters.ps1

function Get-ProjectEntryPointPath
{
    param(
        [parameter(mandatory=$true)]
        [string]$projectFilePath
    )

    $projectDirectoryPath = Split-Path -Parent $projectFilePath

    $projectRootFilePaths = Get-ChildFilePaths -directoryPath $projectDirectoryPath
    
    $appCsEntryPointPath = Select-SinglePathByFileName `
        -fromPaths $projectRootFilePaths `
        -fileName "App.xaml.cs"

    $programCsEntryPointPath = Select-SinglePathByFileName `
        -fromPaths $projectRootFilePaths `
        -fileName "Program.cs"

    if ($appCsEntryPointPath -ne $null)
    {
        return $appCsEntryPointPath
    }

    if ($programCsEntryPointPath -ne $null)
    {
        return $programCsEntryPointPath
    }

    Write-Error "There is no entry point detected for the $projectFilePath"
}

function Get-EmbeddedAssemblies
{
    param(
        [Parameter(Mandatory=$true)]
        [string]$projectFilePath
    )

    [xml]$projectFileContent = Get-Content $projectFilePath

    return $projectFileContent.Project.ItemGroup `
        | % { Set-StrictMode -Off; return $_.EmbeddedResource } `
        | where { $_ -ne $null } `
        | % { $_.Include } `
        | % { $_ | Split-Path -Leaf } `
        | where { Is-AssemblyFile $_ }
}

function Get-ReferencedProjects
{
    param(
        [Parameter(Mandatory=$true)]
        [xml]$projectFileContent
    )

    $referencedProjectsRelativePaths = $projectFileContent.Project.ItemGroup `
        | % { Set-StrictMode -Off; return $_.ProjectReference.Include } `
        | where { $_ -ne $null }

    return $referencedProjectsRelativePaths `
        | %{ 
            $referencedProjectDirectory = Join-Path (Split-Path -Parent $projectFilePath) $_ | Split-Path -Parent
            $referencedProjectName = (Split-Path -Leaf $_) -replace ".csproj", ""

            $referencedProject = {}
            $referencedProject | Add-Member Name $referencedProjectName
            $referencedProject | Add-Member Directory $referencedProjectDirectory

            return $referencedProject
        }
}

function Get-ReferencedProjectPaths
{
     param(
        [Parameter(Mandatory=$true)]
        [xml]$projectContent,

        [Parameter(Mandatory=$true)]
        [string]$projectDirectoryPath
    )

    $referencedProjects = @(Get-ReferencedProjects -projectFileContent $projectContent)

    $referencedProjectPaths = @($referencedProjects `
        | % { Ensure-PathIsRooted -pathToTest "$($_.Directory)\$($_.Name).csproj" -fallbackPathRoot $projectDirectoryPath } `
        | % { Ensure-PathIsResolved -path $_ } `
        | select -Unique)

    return $referencedProjectPaths | select -Unique
}

function Get-ReferencedStaticAssemblyPaths
{
    param(
        [Parameter(Mandatory=$true)]
        [xml]$projectContent,

        [Parameter(Mandatory=$true)]
        [string]$projectDirectoryPath
    )

    return $projectContent.Project.ItemGroup `
        | % { Set-StrictMode -Off; return $_.Reference.HintPath } `
        | where { $_ -ne $null } `
        | where { Is-AssemblyFile $_ } `
        | % { Ensure-PathIsRooted -pathToTest $_ -fallbackPathRoot $projectDirectoryPath } `
        | % { Ensure-PathIsResolved -path $_ } `
        | select -Unique
}

function Get-OutputAssemblyName
{
    param(
        [Parameter(Mandatory=$true)]
        [string]$projectFilePath
    )

    [xml]$projectContent = Get-Content $projectFilePath

    $propertyGroupNodes = $projectContent.Project.PropertyGroup

    return $propertyGroupNodes `
        | where { Has-Property -psObject $_ -propertyName "AssemblyName" } `
        | select -ExpandProperty "AssemblyName" -First 1 { $_.AssemblyName }
}

function Get-ProjectDependencies
{
    param(
        [Parameter(Mandatory=$true)]
        [string]$projectFilePath,
        
        [bool]$recursive = $false,

        [array]$projectsToSkip = @()
    )

    $projectDirectory = Split-Path -Parent $projectFilePath
    [xml]$projectContent = Get-Content $projectFilePath

    $referencedProjectPaths = @(Get-ReferencedProjectPaths -projectContent $projectContent -projectDirectoryPath $projectDirectory)
    $referencedStaticAssemblyPaths = @(Get-ReferencedStaticAssemblyPaths -projectContent $projectContent -projectDirectoryPath $projectDirectory)
    $analyzedProjects = @($projectFilePath)

    if ($recursive) {
        $directReferencedProjectPaths = $referencedProjectPaths
        $directReferencedStaticAssemblyPaths = $referencedStaticAssemblyPaths

        $directReferencedProjectPaths `
            | % {
                    if (-Not ($projectsToSkip.Contains($_)))
                    {
                        $referencedProjectDependencies = Get-ProjectDependencies -projectFilePath $_ -recursive $true -projectsToSkip $projectsToSkip

                        $referencedProjectPaths += $referencedProjectDependencies.ReferencedProjectPaths
                        $referencedStaticAssemblyPaths += $referencedProjectDependencies.ReferencedStaticAssemblyPaths 

                        $analyzedProjects += $referencedProjectDependencies.AnalyzedProjects
                        $projectsToSkip += $referencedProjectDependencies.AnalyzedProjects
                    }
                }
    }

    $projectDependencies = @{}

    $projectDependencies | Add-Member ReferencedProjectPaths @($referencedProjectPaths | select -Unique)
    $projectDependencies | Add-Member ReferencedStaticAssemblyPaths @($referencedStaticAssemblyPaths | select -Unique)
    $projectDependencies | Add-Member AnalyzedProjects @($analyzedProjects | select -Unique)

    return $projectDependencies
}