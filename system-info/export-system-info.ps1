# Define the path to save the output file
$outputFile = "$env:USERPROFILE\Desktop\system_info.txt"

# Collect system information
$systemInfo = Get-ComputerInfo | Select-Object CsName, WindowsVersion, OsArchitecture, CsManufacturer, CsModel, BiosSeralNumber, CsTotalPhysicalMemory
$cpuInfo = Get-CimInstance Win32_Processor | Select-Object Name, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed
$gpuInfo = Get-CimInstance Win32_VideoController | Select-Object Name, AdapterRAM
$diskInfo = Get-PhysicalDisk | Select-Object MediaType, Size, Model
$ramInfo = Get-CimInstance Win32_PhysicalMemory | Select-Object Manufacturer, Capacity, Speed

# Format the information as text
$output = @"
===========================
  SYSTEM INFORMATION
===========================

Computer Name: $($systemInfo.CsName)
Windows Version: $($systemInfo.WindowsVersion)
Architecture: $($systemInfo.OsArchitecture)
Manufacturer: $($systemInfo.CsManufacturer)
Model: $($systemInfo.CsModel)
BIOS Serial Number: $($systemInfo.BiosSeralNumber)
Total Physical Memory: $([math]::Round($systemInfo.CsTotalPhysicalMemory / 1GB, 2)) GB

===========================
  CPU INFORMATION
===========================

Processor: $($cpuInfo.Name)
Cores: $($cpuInfo.NumberOfCores)
Logical Processors: $($cpuInfo.NumberOfLogicalProcessors)
Max Clock Speed: $($cpuInfo.MaxClockSpeed) MHz

===========================
  GPU INFORMATION
===========================

Graphics Card: $($gpuInfo.Name)
VRAM: $([math]::Round($gpuInfo.AdapterRAM / 1GB, 2)) GB

===========================
  DISK INFORMATION
===========================

$($diskInfo | ForEach-Object { "Disk: $($_.Model) - Type: $($_.MediaType) - Size: $([math]::Round($_.Size / 1TB, 2)) TB" })

===========================
  RAM INFORMATION
===========================

$($ramInfo | ForEach-Object { "Manufacturer: $($_.Manufacturer) - Capacity: $([math]::Round($_.Capacity / 1GB, 2)) GB - Speed: $($_.Speed) MHz" })

===========================
"@

# Save the information to the file
$output | Out-File -Encoding UTF8 -FilePath $outputFile

# Display success message
Write-Host "System information exported to $outputFile" -ForegroundColor Green
