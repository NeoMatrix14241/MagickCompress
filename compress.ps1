# Define folder paths
$baseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$inputFolder = Join-Path $baseDir "input"
$outputFolder = Join-Path $baseDir "output"
$logsFolder = Join-Path $baseDir "logs"
$archiveFolder = Join-Path $baseDir "archive"

# Function to create folder if it doesn't exist
function Ensure-FolderExists {
    param (
        [string]$FolderPath,
        [string]$FolderName
    )
    
    if (-not (Test-Path -Path $FolderPath)) {
        New-Item -ItemType Directory -Path $FolderPath | Out-Null
        Write-Host "Created $FolderName folder: $FolderPath"
    }
}

# Create required folders
Ensure-FolderExists -FolderPath $inputFolder -FolderName "input"
Ensure-FolderExists -FolderPath $outputFolder -FolderName "output"
Ensure-FolderExists -FolderPath $logsFolder -FolderName "logs"
Ensure-FolderExists -FolderPath $archiveFolder -FolderName "archive"

# Start time tracking
$scriptStartTime = Get-Date

# Add log folder path after ScriptDirectory definition
$ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Definition
$logDir = Join-Path $ScriptDirectory "logs"
$logFile = Join-Path $logDir "compress_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# Create log directory if it doesn't exist
if (!(Test-Path -Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}

# Replace Write-Log function with enhanced version
function Write-Log {
    param(
        $Message,
        $Type = "Info"  # Info, Warning, Error, Success
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp][$Type] $Message"
    
    # Write to console with color
    switch ($Type) {
        "Info"    { Write-Host $logMessage -ForegroundColor White }
        "Warning" { Write-Host $logMessage -ForegroundColor Yellow }
        "Error"   { Write-Host $logMessage -ForegroundColor Red }
        "Success" { Write-Host $logMessage -ForegroundColor Green }
    }
    
    # Write to log file
    Add-Content -Path $logFile -Value $logMessage
}

# wag galawin please
$ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Definition

# kung ano ung icocompress
$inputDir = Join-Path $ScriptDirectory "input"
# mga nacompress na
$outputDir = Join-Path $ScriptDirectory "output"
# mga nacompress na files na nilagay sa archive kasi tapos na
$archiveDir = Join-Path $ScriptDirectory "archive"

if (!(Test-Path -Path $inputDir)) {
    Write-Error "Input directory does not exist: $inputDir"
    exit
}

if (Test-Path -Path $outputDir) {
    $confirmation = Read-Host "Output directory already exists. Do you want to overwrite it? (Y/N)"
    if ($confirmation -eq 'Y' -or $confirmation -eq 'y') {
        Remove-Item -Recurse -Force -Path $outputDir
        New-Item -ItemType Directory -Path $outputDir | Out-Null
    } else {
        Write-Error "Operation aborted by the user."
        exit
    }
} else {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

if (!(Test-Path -Path $archiveDir)) {
    New-Item -ItemType Directory -Path $archiveDir | Out-Null
}

# Supported file extensions edit nyo pag meron walang included kaya yn ni imagemagick 7
$supportedExtensions = @("*.tif", "*.bmp", "*.png", "*.gif", "*.jpg", "*.jpeg")

$imageFiles = @()
foreach ($ext in $supportedExtensions) {
    $imageFiles += Get-ChildItem -Path $inputDir -Recurse -Filter $ext
}

Write-Log "----------------------------------------" "Info"
Write-Log "Starting image compression process" "Info"
Write-Log "Found $(($imageFiles | Measure-Object).Count) files to process:" "Info"
$imageFiles | ForEach-Object { Write-Log "- $($_.FullName)" "Info" }
Write-Log "----------------------------------------" "Info"

# Initial verification phase
$initialCorruptedFiles = @()
Write-Log "Performing initial verification of input files..." "Info"

foreach ($file in $imageFiles) {
    Write-Log "Verifying: $($file.FullName)" "Info"
    try {
        & magick identify -ping $file.FullName 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Input file is corrupted or invalid: $($file.FullName)" "Error"
            $initialCorruptedFiles += $file
        } else {
            Write-Log "Verification passed: $($file.FullName)" "Success"
        }
    }
    catch {
        Write-Log "Cannot read input file: $($file.FullName)" "Error"
        $initialCorruptedFiles += $file
    }
}

if ($initialCorruptedFiles.Count -gt 0) {
    Write-Warning "Found $($initialCorruptedFiles.Count) corrupted files in input folder:"
    $initialCorruptedFiles | ForEach-Object { Write-Warning "- $($_.FullName)" }
    Write-Warning "These files will be skipped during processing."
    # Remove corrupted files from processing list
    $imageFiles = $imageFiles | Where-Object { $_.FullName -notin $initialCorruptedFiles.FullName }
}

Write-Output "Starting compression for valid files..."

$cpuThreads = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
$maxThreads = [Math]::Max(1, [Math]::Floor($cpuThreads * 1.00)) # Using 100% of threads
Write-Log "Detected $cpuThreads CPU threads. Using $maxThreads threads for processing." "Info"

# Create synchronized collections for results
$syncResults = [System.Collections.Concurrent.ConcurrentDictionary[string,bool]]::new()

# Process files in parallel
$imageFiles | ForEach-Object -ThrottleLimit $maxThreads -Parallel {
    $file = $_
    $inputDir = $using:inputDir
    $outputDir = $using:outputDir
    # ---------------------------------------------------
    # DITO KAYO MAG EDIT NG QUALITY
    # ---------------------------------------------------
    $quality = 50
    # ---------------------------------------------------
    $syncResults = $using:syncResults
    
    try {
        # Pre-compression verification
        & magick identify -ping $file.FullName 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            $syncResults.TryAdd($file.FullName, $false)
            Write-Error "Input file is corrupted or invalid: $($file.FullName)"
            return
        }

        $relativePath = $file.FullName.Substring($inputDir.Length + 1)
        $outputFileDir = Join-Path $outputDir -ChildPath (Split-Path -Parent $relativePath)
        
        if (!(Test-Path -Path $outputFileDir)) {
            $null = New-Item -ItemType Directory -Path $outputFileDir -Force
        }

        $outputFilePath = Join-Path $outputFileDir "$($file.BaseName)$($file.Extension)"
        
        # Get original file size
        $originalSize = (Get-Item $file.FullName).Length
        
        # Process the image
        $colorspace = & magick identify -format "%[colorspace]" $file.FullName
        & magick $file.FullName -colorspace $colorspace -quality $quality -compress JPEG $outputFilePath

        # Post-compression verification steps
        $verificationSteps = @(
            @{ Step = "Existence Check"; Action = { Test-Path $outputFilePath } }
            @{ Step = "Size Check"; Action = { (Get-Item $outputFilePath).Length -gt 0 } }
            @{ Step = "Integrity Check"; Action = { 
                & magick identify -ping $outputFilePath 2>&1 | Out-Null
                $LASTEXITCODE -eq 0 
            }}
        )

        $verificationPassed = $true
        foreach ($step in $verificationSteps) {
            if (-not (& $step.Action)) {
                $verificationPassed = $false
                Write-Error "Verification failed at $($step.Step) for: $outputFilePath"
                break
            }
        }

        if ($verificationPassed) {
            $newSize = (Get-Item $outputFilePath).Length
            $originalSize = (Get-Item $file.FullName).Length
            
            # Ensure correct size comparison
            $sizeInMB = @{
                Original = [math]::Round($originalSize / 1MB, 2)
                New = [math]::Round($newSize / 1MB, 2)
            }
            
            # Calculate reduction percentage (negative means size increased)
            $savings = [math]::Round(($originalSize - $newSize) / $originalSize * 100, 2)
            
            $compressionInfo = @{
                OriginalSize = $originalSize
                NewSize = $newSize
                Savings = $savings
                Path = $file.FullName
            }
            
            $syncResults.TryAdd($file.FullName, $compressionInfo)
            
            # Format output message with correct size information
            $sizeChange = if ($savings -gt 0) { "Reduced" } else { "Increased" }
            $savingsAbs = [Math]::Abs($savings)
            Write-Output "SUCCESS: $($file.Name) - Original: $($sizeInMB.Original)MB, New: $($sizeInMB.New)MB, Size $sizeChange by $savingsAbs%"
        } else {
            $syncResults.TryAdd($file.FullName, $false)
            if (Test-Path $outputFilePath) { Remove-Item -Path $outputFilePath -Force }
        }
    }
    catch {
        $syncResults.TryAdd($file.FullName, $false)
        Write-Error "Error processing file: $($file.FullName)"
        Write-Error $_.Exception.Message
        if (Test-Path $outputFilePath) { Remove-Item -Path $outputFilePath -Force }
    }
}

# Process results
$successfulFiles = $syncResults.GetEnumerator() | Where-Object { $_.Value -ne $false }
$failedFiles = $syncResults.GetEnumerator() | Where-Object { $_.Value -eq $false }

# Function to safely move file to archive with folder structure
function Move-FileToArchive {
    param($SourcePath, $ArchiveDir, $BaseSourceDir)
    
    try {
        # Ensure we have valid input
        if ([string]::IsNullOrEmpty($SourcePath) -or [string]::IsNullOrEmpty($ArchiveDir) -or [string]::IsNullOrEmpty($BaseSourceDir)) {
            Write-Log "Invalid parameters provided to Move-FileToArchive" "Error"
            return $false
        }

        # Get relative path from base directory
        if ($SourcePath -like "*$BaseSourceDir*") {
            $relativePath = $SourcePath.Substring($BaseSourceDir.Length).TrimStart('\')
        } else {
            $relativePath = Split-Path -Leaf $SourcePath
        }
        
        $targetDir = Join-Path $ArchiveDir (Split-Path -Parent $relativePath)
        
        # Create target directory if it doesn't exist
        if (!(Test-Path -Path $targetDir)) {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        }
        
        $fileName = Split-Path -Leaf $SourcePath
        $destPath = Join-Path $targetDir $fileName
        
        # Handle file name conflicts
        if (Test-Path $destPath) {
            $fileNameOnly = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
            $extension = [System.IO.Path]::GetExtension($fileName)
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $newFileName = "${fileNameOnly}_${timestamp}${extension}"
            $destPath = Join-Path $targetDir $newFileName
        }
        
        # Perform the move
        if (Test-Path $SourcePath) {
            Move-Item -Path $SourcePath -Destination $destPath -Force
            return $true
        }
        return $false
    }
    catch {
        Write-Log "Error moving file $SourcePath to archive: $_" "Error"
        return $false
    }
}

# Process results and move files
Write-Log "Moving successful files to archive..." "Info"
foreach ($result in $successfulFiles) {
    $filePath = $result.Key
    Write-Log "Moving file: $filePath" "Info"
    $moveResult = Move-FileToArchive -SourcePath $filePath -ArchiveDir $archiveDir -BaseSourceDir $inputDir
    if (-not $moveResult) {
        Write-Log "Failed to move file to archive: $filePath" "Error"
    }
}

# Add elapsed time calculation and enhanced summary at the end
$scriptEndTime = Get-Date
$elapsedTime = $scriptEndTime - $scriptStartTime
$elapsedFormatted = "{0:D2}h:{1:D2}m:{2:D2}s" -f $elapsedTime.Hours, $elapsedTime.Minutes, $elapsedTime.Seconds

Write-Log "----------------------------------------" "Info"
Write-Log "Process Summary" "Info"
Write-Log "----------------------------------------" "Info"
Write-Log "Start Time: $scriptStartTime" "Info"
Write-Log "End Time: $scriptEndTime" "Info"
Write-Log "Total Duration: $elapsedFormatted" "Info"
Write-Log "Processed files: $($imageFiles.Count)" "Info"
Write-Log "Successful: $($successfulFiles.Count)" "Info"
Write-Log "Failed during processing: $($failedFiles.Count)" "Info"
Write-Log "Initially corrupted/skipped: $($initialCorruptedFiles.Count)" "Warning"

Write-Log "----------------------------------------" "Info"
Write-Log "Detailed Processing Results" "Info"
Write-Log "----------------------------------------" "Info"

Write-Log "Successfully Processed Files:" "Success"
foreach ($file in $successfulFiles) {
    $info = $file.Value
    Write-Log "- $($file.Key)" "Success"
    Write-Log "  Original: $([math]::Round($info.OriginalSize/1MB, 2))MB" "Info"
    Write-Log "  Compressed: $([math]::Round($info.NewSize/1MB, 2))MB" "Info"
    Write-Log "  Reduction: $($info.Savings)%" "Info"
}

Write-Log "----------------------------------------" "Info"
Write-Log "Failed Files:" "Error"
foreach ($file in $failedFiles) {
    Write-Log "- $($file.Key)" "Error"
}

if ($initialCorruptedFiles.Count -gt 0) {
    Write-Log "The following files were skipped due to corruption:" "Warning"
    $initialCorruptedFiles | ForEach-Object { Write-Log "- $($_.FullName)" "Warning" }
}
if ($failedFiles.Count -gt 0) {
    Write-Log "The following files failed during processing:" "Error"
    $failedFiles | ForEach-Object { Write-Log "- $($_.Key)" "Error" }
}
Write-Log "----------------------------------------" "Info"
Write-Log "Log file saved to: $logFile" "Info"