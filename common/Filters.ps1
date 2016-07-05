function Any 
{
    param
	(
		[Parameter(Mandatory=$true)]
		$predicate,
		
		[Parameter(ValueFromPipeline = $true)] 
		$objectToTest
	)	
        
    begin {
        $any = $false
    }
    process {
        if (-not $any -and (& $predicate $objectToTest)) 
		{
            $any = $true
        }
    }
    end {
        return $any
    }
}

function Substring
{
    param(
        [parameter(ValueFromPipeline = $true)]
        [string]$inputString,

        [string]$beforeFirst
    )

    if ($beforeFirst -ne $null)
    {
        $substringStartIndex = $inputString.IndexOf($beforeFirst)

        if ($substringStartIndex -ge 0) {
            return $inputString.Substring(0, $substringStartIndex)
        }

        else {
            return $inputString
        }
    }
}

function Replace
{
    param(
        [parameter(ValueFromPipeline=$true)]
        [string]$inputString,

        [parameter(mandatory=$true)]
        [string]$pattern,

        [parameter(mandatory=$true)]
        [string]$on
    )

    $inputString -replace $pattern, $on
}