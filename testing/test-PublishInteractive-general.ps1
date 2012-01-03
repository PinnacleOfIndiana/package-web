param($testOutputRoot)
# set-psdebug -strict -trace 0

$script:succeeded = $true
# define all test cases here
function TestGetPathToMSDeploy01 {
    try {
        $expectedMsdeployExe = "C:\Program Files\IIS\Microsoft Web Deploy V2\msdeploy.exe"    
        $actualMsdeployExe = GetPathToMSDeploy
        
        $msg = "TestGetPathToMSDeploy01"
        AssertNotNull $actualMsdeployExe $msg
        AssertEqual $expectedMsdeployExe $actualMsdeployExe
        if(!(RaiseAssertions)) { $script:succeeded = $false }
    }
    catch{
        $script:succeeded = $false
    }
}

# ExtractZip test cases
function TestExtractZip-Default {
    try {
        # extract the
        $zipFile = ((Join-Path $testOutputRoot -ChildPath "test-resources\SampleZip.zip" | Get-Item).FullName | Resolve-Path).Path
        $destFolder = Join-Path $testOutputRoot -ChildPath "psout\SampleZip"

        if(Test-Path $destFolder) {
            Remove-Item -Path $destFolder -Recurse
        }
        New-Item -Path $destFolder -type directory
        
        $destFolder =  ($destFolder| Resolve-Path).Path
        
        $expectedResults = @("SampleZip",
                             "SampleZip\subfolder01",
                             "SampleZip\subfolder02",
                             "SampleZip\file01.txt",
                             "SampleZip\file02.txt",
                             "SampleZip\subfolder01\file01.txt",
                             "SampleZip\subfolder01\file02.txt",
                             "SampleZip\subfolder02\file01.txt",
                             "SampleZip\subfolder02\file02.txt")
            
        Extract-Zip -zipFilename $zipFile -destination $destFolder
        $extractedItems = Get-ChildItem $destFolder -Recurse
        $actualResults = @()
                
        foreach($item in $extractedItems) {
            $actualResults += $item.FullName.Substring($destFolder.Length + 1)
        }        
        
        AssertNotNull $extractedItems "not-null: extractedItems"
        AssertEqual $expectedResults.Length $actualResults.Length  "$expectedResults.Length $actualResults.Length"
        for($i = 0; $i -lt $expectedResults.Length; $i++) {
            AssertEqual $expectedResults[$i] $actualResults[$i] ("exp-actual loop index {0}" -f $i)
        }
                
        if(!(RaiseAssertions)) { $script:succeeded = $false }
    }
    catch{
        $script:succeeded = $false
        $_.Exception | Write-Error | Out-Null
    }
}

function TestExtractZip-ZipDoesntExist {
    $exceptionThrown = $false
    try {
        $destFolder = (Join-Path $testOutputRoot -ChildPath "psout\SampleZip" | Resolve-Path).Path
        # -Intent $Intention.ShouldFail
        $zipFile = "C:\some\non-existing-path\123454545454545.zip"
        Extract-Zip -zipFilename $zipFile -destination $destFolder
    }
    catch {
        $exceptionThrown = $true
        AssertEqual "System.IO.FileNotFoundException" $_.Exception.GetType().FullName "TestExtractZip-ZipDoesntExist exception type check"
    }
    
    AssertEqual $true $exceptionThrown "$true $exceptionThrown"    
    if(!(RaiseAssertions)) { $script:succeeded = $false }
}

function TestExtractZip-DestDoesntExist {
    $exceptionThrown = $false
    
    try {
        $zipFile = ((Join-Path $testOutputRoot -ChildPath "test-resources\SampleZip.zip" | Get-Item).FullName | Resolve-Path).Path
        $destFolder = "C:\some\non-existing-path\12345454545454577777d454545\"
        Extract-Zip -zipFilename $zipFile -destination $destFolder
    }
    catch {
        $exceptionThrown = $true
        AssertEqual $true $_.Exception.Message.ToLower().Contains("destination not found at") "TestExtractZip-DestDoesntExist: checking exception msg"
    }
    
    AssertEqual $true $exceptionThrown "TestExtractZip-DestDoesntExist: $true $exceptionThrown"    
    if(!(RaiseAssertions)) { $script:succeeded = $false }
}

# GetZipFileForPublishing test cases

function TestGetZipFileForPublishing-1ZipInFolder {
    try {
        $zipFile = ((Join-Path $testOutputRoot -ChildPath "test-resources\SampleZip.zip" | Get-Item).FullName | Resolve-Path).Path
        $destFolder = Join-Path $testOutputRoot -ChildPath "psout\SampleZip"
        
        # delete the dest folder and re-create it to ensure there is only 1 zip file
        if(Test-Path $destFolder) {
            Remove-Item -Path $destFolder -Recurse
        }
        New-Item -Path $destFolder -type directory
        $destFolder =  ($destFolder| Resolve-Path).Path
        
        Copy-Item -Path $zipFile -Destination $destFolder
        
        $zipResult = GetZipFileForPublishing -rootFolder $destFolder
        AssertNotNull $zipResult "TestGetZipFileForPublishing-1ZipInFolder: zipResult"        
        AssertEqual (Get-Item $zipFile).Name $zipResult.Name "TestGetZipFileForPublishing-1ZipInFolder: zipFile.Name zipResult.Name"
        
        if(!(RaiseAssertions)) { $script:succeeded = $false }
    }
    catch {
        $script:succeeded = $false
        $_.Exception | Write-Error | Out-Null
    }
}

function TestGetZipFileForPublishing-NoZipInFolder {
    try {
        $zipFile = ((Join-Path $testOutputRoot -ChildPath "test-resources\SampleZip.zip" | Get-Item).FullName | Resolve-Path).Path
        $destFolder = Join-Path $testOutputRoot -ChildPath "psout\SomeEmptyFolder"
        
        # delete the dest folder and re-create it to ensure there is only 1 zip file
        if(Test-Path $destFolder) {
            Remove-Item -Path $destFolder -Recurse
        }
        New-Item -Path $destFolder -type directory
        $destFolder =  ($destFolder| Resolve-Path).Path
        
        $zipResult = GetZipFileForPublishing -rootFolder $destFolder
    }
    catch {
        AssertEqual $true $_.Exception.Message.ToLower().Contains("no web package (.zip file) found in folder") "TestGetZipFileForPublishing-NoZipInFolder: Exception msg"
    }
    
    if(!(RaiseAssertions)) { $script:succeeded = $false }
}

# GetTransforms test cases
function TestGetTransforms-TransformsExist {
    try {
        $srcFolder = ((Join-Path $testOutputRoot -ChildPath "test-resources\\transforms" | Get-Item).FullName | Resolve-Path).Path
        $destFolder = Join-Path $testOutputRoot -ChildPath "psout\SomeEmptyFolder"
        # delete the dest folder and re-create it to ensure there is only 1 zip file
        if(Test-Path $destFolder) {
            Remove-Item -Path $destFolder -Recurse
        }
        New-Item -Path $destFolder -type directory
        
        # copy sample config transforms into that folde
        Get-ChildItem -Path $srcFolder | Copy-Item -Destination $destFolder
        $result = GetTransforms -deployTempFolder $destFolder
        
        $expectedResult = @("Debug",
                            "Prod",
                            "Release",
                            "Test")
        AssertNotNull $result "TestGetTransforms-TransformsExist: result not null"
        AssertEqual $expectedResult.Length $result.Length "TestGetTransforms-TransformsExist: result length"
        for($i=0; $i -lt $expectedResult.Length; $i++){
            AssertEqual $result[$i] $expectedResult[$i] ("TestGetTransforms-TransformsExist: exp-actual loop index [{0}]" -f $i)
        }
        
        if(!(RaiseAssertions)) { $script:succeeded = $false }
    }
    catch {
        $script:succeeded = $false
        $_.Exception | Write-Error | Out-Null
    }
}

function TestGetTransforms-TransformsDoNotExist {
    try {
        $srcFolder = ((Join-Path $testOutputRoot -ChildPath "test-resources\\transforms" | Get-Item).FullName | Resolve-Path).Path
        $destFolder = Join-Path $testOutputRoot -ChildPath "psout\SomeEmptyFolder"
        # delete the dest folder and re-create it to ensure there is only 1 zip file
        if(Test-Path $destFolder) {
            Remove-Item -Path $destFolder -Recurse
        }
        New-Item -Path $destFolder -type directory
        
        $result = GetTransforms -deployTempFolder $destFolder
        
        AssertNull $result "TestGetTransforms-TransformsDoNotExist: result is null"
        
        if(!(RaiseAssertions)) { $script:succeeded = $false }
    }
    catch {
        $script:succeeded = $false
        $_.Exception | Write-Error | Out-Null
    }
}

# GetParametersFromPackage related tests
function TestGetParametersFromPackage-Default {
    try {
        $zipFile = ((Join-Path $testOutputRoot -ChildPath "test-resources\SampleWebPackage-Default.zip" | Get-Item).FullName | Resolve-Path).Path
        $tempFolder = Join-Path $testOutputRoot -ChildPath "psout\TestGetParametersFromPackage-Default"
        # delete the dest folder and re-create it to ensure there is only 1 zip file
        if(Test-Path $tempFolder) {
            Remove-Item -Path $tempFolder -Recurse
        }
        New-Item -Path $tempFolder -type directory

        $parameters = GetParametersFromPackage -packagePath $zipFile -tempPublishFolder $tempFolder
        AssertNotNull $parameters "TestGetParametersFromPackage-Default: parameters not null"
        AssertEqual 2 $parameters.length "TestGetParametersFromPackage-Default: parameters length"
        
        AssertEqual "IIS Web Application Name" $parameters[0].name "TestGetParametersFromPackage-Default: parameter 0 name"
        AssertEqual "Default Web Site/SampleWeb_deploy" $parameters[0].defaultValue "TestGetParametersFromPackage-Default: parameter 0 defaultValue"
        
        AssertEqual "ApplicationServices-Web.config Connection String" $parameters[1].name "TestGetParametersFromPackage-Default: parameter 1 name"
        AssertEqual "data source=.\SQLEXPRESS;Integrated Security=SSPI;AttachDBFilename=|DataDirectory|\aspnetdb.mdf;User Instance=true" $parameters[1].defaultValue "TestGetParametersFromPackage-Default: parameter 1 value"
        
        if(!(RaiseAssertions)) { $script:succeeded = $false }
    }
    catch {
        $script:succeeded = $false
        $_.Exception | Write-Error | Out-Null
    }
}

function TestGetParametersFromPackage-PackageDoesntExist {
    $raisedException = $false
    
    try {
        $zipFile = "C:\temp\somepath\which\doesnt\exist\foo.zip"
        $tempFolder = Join-Path $testOutputRoot -ChildPath "psout\TestGetParametersFromPackage-PackageDoesntExist"
        # delete the dest folder and re-create it to ensure there is only 1 zip file
        if(Test-Path $tempFolder) {
            Remove-Item -Path $tempFolder -Recurse
        }
        New-Item -Path $tempFolder -type directory
        
        $parameters = GetParametersFromPackage -packagePath $zipFile -tempPublishFolder $tempFolder
    }
    catch {
        $raisedException = $true
        AssertEqual "System.IO.FileNotFoundException" $_.Exception.GetType().FullName "TestGetParametersFromPackage-PackageDoesntExist: exception type check"
    }
    
    AssertEqual $true $raisedException "TestGetParametersFromPackage-PackageDoesntExist: raisedException"
    
    if(!(RaiseAssertions)) { $script:succeeded = $false }
}

function TestGetParametersFromPackage-NoValForPackagePath {
    $raisedException = $false
    try {
        $tempFolder = Join-Path $testOutputRoot -ChildPath "psout\TestGetParametersFromPackage-PackageDoesntExist"
        # delete the dest folder and re-create it to ensure there is only 1 zip file
        if(Test-Path $tempFolder) {
            Remove-Item -Path $tempFolder -Recurse
        }
        New-Item -Path $tempFolder -type directory
        $parameters = GetParametersFromPackage -tempPublishFolder $tempFolder
    }
    catch {
        $raisedException = $true
        AssertEqual $true $_.Exception.Message.ToLower().Contains("packagepath is a required") "TestGetParametersFromPackage-NoValForPackagePath: exception text"
    }
    
    AssertEqual $true $raisedException "TestGetParametersFromPackage-NoValForPackagePath: raisedException"
    if(!(RaiseAssertions)) { $script:succeeded = $false }
}

function TestGetParametersFromPackage-NoValForTempFolder {
    $raisedException = $false
    try {
        $zipFile = ((Join-Path $testOutputRoot -ChildPath "test-resources\SampleWebPackage-Default.zip" | Get-Item).FullName | Resolve-Path).Path

        $parameters = GetParametersFromPackage -packagePath $zipFile
    }
    catch {
        $raisedException = $true
        AssertEqual $true $_.Exception.Message.ToLower().Contains("temppublishfolder is a required") "TestGetParametersFromPackage-NoValForTempFolder: exception text"
    }
    
    AssertEqual $true $raisedException "TestGetParametersFromPackage-NoValForTempFolder: raisedException"
    if(!(RaiseAssertions)) { $script:succeeded = $false }
}


# ConvertTo-PlainText test cases
function TestConvertTo-PlainText {
    try {
        $plainText = "some random string(#99393 here"
        $secureString = ConvertTo-SecureString $plainText -asplaintext -force
        
        $actualResult = ConvertTo-PlainText -secureString $secureString
        AssertEqual $plainText $actualResult "TestConvertTo-PlainText: conversion"
        
        if(!(RaiseAssertions)) { $script:succeeded = $false }
    }
    catch {
        $script:succeeded = $false
        $_.Exception | Write-Error | Out-Null
    }
}

function TestConvertTo-PlainText-NoValueForSecureString {
    $raisedException = $false
    
    try {
        ConvertTo-PlainText
        AssertEqual $plainText $actualResult "TestConvertTo-PlainText: conversion"       
    }
    catch {
        $raisedException = $true
        AssertEqual $true $_.Exception.Message.ToLower().Contains("securestring is a required") "TestConvertTo-PlainText-NoValueForSecureString: exception message"
    }
    
    if(!(RaiseAssertions)) { $script:succeeded = $false }
}

# G:\Data\Development\My Code\package-web\OutputRoot\tests\psout\empty
function TestTemplate {
    try {
        
        
        
        
        if(!(RaiseAssertions)) { $script:succeeded = $false }
    }
    catch {
        $script:succeeded = $false
        $_.Exception | Write-Error | Out-Null
    }
}





$currentDirectory = split-path $MyInvocation.MyCommand.Definition -parent
# Run the initilization script
& (Join-Path -Path $currentDirectory -ChildPath "setup-testing.ps1")

# start running test cases
TestExtractZip-Default
TestExtractZip-ZipDoesntExist
TestExtractZip-DestDoesntExist

TestGetZipFileForPublishing-1ZipInFolder
TestGetZipFileForPublishing-NoZipInFolder

TestGetTransforms-TransformsExist
TestGetTransforms-TransformsDoNotExist

TestGetParametersFromPackage-Default
TestGetParametersFromPackage-PackageDoesntExist

TestGetParametersFromPackage-NoValForPackagePath
TestGetParametersFromPackage-NoValForTempFolder

TestConvertTo-PlainText
TestConvertTo-PlainText-NoValueForSecureString

# Run the tear-down script
& (Join-Path -Path $currentDirectory -ChildPath "teardown-testing.ps1")
ExitScript -succeeded $script:succeeded -sourceScriptFile $MyInvocation.MyCommand.Definition