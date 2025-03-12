# Ensure the script runs as Administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Restarting script as Administrator..."
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Define report file path (saved to Desktop)
$desktopPath = [System.IO.Path]::Combine($env:USERPROFILE, "Desktop")
$reportFile = [System.IO.Path]::Combine($desktopPath, "disk_cleanup_report.txt")

# Function to get total disk space usage
function Get-DiskUsage {
    $disk = Get-PSDrive C
    $freeSpaceGB = [math]::Round($disk.Free / 1GB, 2)
    $totalSizeGB = [math]::Round($disk.Used / 1GB, 2) + $freeSpaceGB
    return $freeSpaceGB, $totalSizeGB
}

# Function to get storage usage per folder
function Get-StorageUsage {
    param ($label)

    $totalSize = 0
    $folders = @(
        "$env:USERPROFILE\AppData\Local\Temp",
        "$env:WINDIR\Temp",
        "$env:SystemRoot\Prefetch",
        "$env:SystemDrive\Windows\Logs",
        "$env:USERPROFILE\AppData\Local\Microsoft\Windows\Explorer",
        "$env:USERPROFILE\AppData\Local\Microsoft\Windows\INetCache"
    )

    $reportContent = "===========================`n"
    $reportContent += " DISK STORAGE USAGE ($label) `n"
    $reportContent += "===========================`n`n"

    foreach ($folder in $folders) {
        if (Test-Path $folder) {
            $size = (Get-ChildItem -Path $folder -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
            $sizeGB = if ($size -gt 0) { [math]::Round($size / 1GB, 2) } else { 0 }
            $reportContent += "Folder: $folder - Used: $sizeGB GB`n"
            $totalSize += $size
        }
    }

    $totalSizeGB = [math]::Round($totalSize / 1GB, 2)
    $reportContent += "`nTotal Storage Used ($label): $totalSizeGB GB`n"

    return $reportContent, $totalSizeGB
}

# Function to delete files from a specific folder (without confirmation)
function Clean-Folder {
    param ($folderPath, $logFile)

    if (Test-Path $folderPath) {
        Get-ChildItem -Path $folderPath -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer } | ForEach-Object {
            $fileSize = [math]::Round($_.Length / 1MB, 2)
            $log = "Deleted: $($_.FullName) - Size: ${fileSize}MB"
            $log | Out-File -Append -Encoding UTF8 -FilePath $logFile
            Remove-Item $_.FullName -Force -Confirm:$false -ErrorAction SilentlyContinue
        }
        Write-Host "Cleaned: $folderPath"
    } else {
        Write-Host "Folder not found: $folderPath"
    }
}

# Function to forcefully empty the Recycle Bin (No pop-ups)
function Empty-RecycleBin {
    Write-Host "Forcefully emptying Recycle Bin..."
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    Write-Host "Recycle Bin emptied successfully"
}

# Function to run Windows built-in Disk Cleanup silently
function Run-DiskCleanup {
    Write-Host "Running Windows Disk Cleanup..."
    Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/verylowdisk" -NoNewWindow -Wait
    Write-Host "Windows Disk Cleanup completed"
}

# Capture total disk usage before cleanup
$beforeFreeSpace, $beforeTotalSize = Get-DiskUsage

# Capture storage usage before cleanup
$beforeReport, $beforeSize = Get-StorageUsage -label "Before Cleanup"

# List of folders to be cleaned
$tempFolders = @(
    "$env:USERPROFILE\AppData\Local\Temp",
    "$env:WINDIR\Temp",
    "$env:SystemRoot\Prefetch",
    "$env:SystemDrive\Windows\Logs",
    "$env:USERPROFILE\AppData\Local\Microsoft\Windows\Explorer",
    "$env:USERPROFILE\AppData\Local\Microsoft\Windows\INetCache"
)

# Create cleanup log file
$logFile = [System.IO.Path]::Combine($desktopPath, "deleted_files_log.txt")
"Deleted Files Log:`n===========================" | Out-File -Encoding UTF8 -FilePath $logFile

# Execute cleanup for each temp folder
foreach ($folder in $tempFolders) {
    Clean-Folder -folderPath $folder -logFile $logFile
}

# Ask user if they want to delete the Downloads folder
$deleteDownloads = Read-Host "Do you want to delete the Downloads folder? (1 - Yes, 2 - No)"

if ($deleteDownloads -eq "1") {
    $downloadsPath = "$env:USERPROFILE\Downloads"
    if (Test-Path $downloadsPath) {
        Clean-Folder -folderPath $downloadsPath -logFile $logFile
        Write-Host "Downloads folder cleaned"
    }
} else {
    Write-Host "Downloads folder was not deleted"
}

# Forcefully empty the Recycle Bin
Empty-RecycleBin

# Run Windows built-in Disk Cleanup tool
Run-DiskCleanup

# Capture total disk usage after cleanup
$afterFreeSpace, $afterTotalSize = Get-DiskUsage

# Capture storage usage after cleanup
$afterReport, $afterSize = Get-StorageUsage -label "After Cleanup"

# Calculate space freed
$spaceFreed = [math]::Round($beforeSize - $afterSize, 2)
$diskSpaceFreed = [math]::Round($afterFreeSpace - $beforeFreeSpace, 2)

# Generate final report
$finalReport = "===========================`n"
$finalReport += " DISK CLEANUP REPORT `n"
$finalReport += "===========================`n`n"
$finalReport += "Total Disk Space Before Cleanup: $beforeFreeSpace GB Free / $beforeTotalSize GB Total`n"
$finalReport += "Total Disk Space After Cleanup:  $afterFreeSpace GB Free / $afterTotalSize GB Total`n"
$finalReport += "`nTotal Space Freed on Disk: $diskSpaceFreed GB`n"
$finalReport += "`n$beforeReport`n"
$finalReport += "$afterReport`n"
$finalReport += "===========================`n"
$finalReport += " TOTAL TEMP FILES DELETED: $spaceFreed GB `n"
$finalReport += "===========================`n"

# Save report
$finalReport | Out-File -Encoding UTF8 -FilePath $reportFile
Write-Host "Final cleanup report saved to: $reportFile"
Write-Host "Deleted files log saved to: $logFile"

Write-Host "Full disk cleanup completed successfully"