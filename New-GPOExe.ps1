<#
.SYNOPSIS
  Creates an execuble that can apply and remove a local Group Policy Object
.DESCRIPTION
 Creates an execuble that can apply and remove a specific local policy. The executable is a self-extracting winrar archive. Winrar installation is required for processing.
 The execuble will work in "MERGE" mode, meaning that settings that are duplicate will be overwritten, other settings will not be touched.
 
 Parameters are not required, but optional. Script will fail if LGPO and Winrar are not present.
 
 WARNING: SCRIPT IS DESTRUCTIVE TO LOCAL GROUP POLICIES. DO NOT RUN ON PRODUCTION MACHINES. Use at own risk.
.PARAMETER DownloadURL
    Specificies where to download LGPO from if not installed.
.PARAMETER DownloadLocation
    Specificies where to download LGPO to if not installed. Defaults to C:\Temp\LGPO
.PARAMETER WorkingPath
    Specificies where to put temporary files. Defaults to C:\Temp\LGPO
.PARAMETER WinrarPath
    Path where winrar is found. Defaults to C:\Program Files\WinRAR\WinRAR.exe
.PARAMETER GPOName
    Decides part of the name of the file that will be placed in C:\ProgramData\
.PARAMETER GPOVersion
    Decides part of the name of the file that will be placed in C:\ProgramData\
.INPUTS
  none
.OUTPUTS
  executable generated and stored in user desktop location
.NOTES
  Version:        0.4
  Author:         Kelvin Tegelaar
  Creation Date:  02/2020
  Purpose/Change: Initial script. Beta.
 
#>
Param(
    [string]$DownloadURL = "http://cyberdrain.com/wp-content/uploads/2020/02/LGPO.exe",
    [string]$DownloadLocation = "C:\Temp\LGPO",
    [string]$WinrarPath = "C:\Program Files\WinRAR\WinRAR.exe",
    [string]$GPOName = "GPO",
    [string]$GPOVersion = "1.0"
)
 
write-host "Checking if base folder exists in $DownloadLocation and if not, creating it." -ForegroundColor Green
try {
    $TestDownloadLocation = Test-Path $DownloadLocation
    if (!$TestDownloadLocation) {
        write-host "Creating Folder to download LGPO." -ForegroundColor Green
        new-item $DownloadLocation -ItemType Directory -force
    }
    $TestDownloadLocationExe = Test-Path "$DownloadLocation\LGPO.exe"
    if (!$TestDownloadLocationExe) { 
        write-host "Download LGPO." -ForegroundColor Green
        Invoke-WebRequest -UseBasicParsing -Uri $DownloadURL -OutFile "$DownloadLocation\LGPO.exe"
    }
    $TestDownloadLocationBat = Test-Path "$DownloadLocation\LGPOExecute.bat"
    if (!$TestDownloadLocationBat) { 
        write-host "Generating configuration batch file." -ForegroundColor Green
 
        @"
LGPO.exe /t ComputerPolicy.txt /v > "C:\ProgramData\$GPOName $GPOVersion Computer.log"
LGPO.exe /t UserPolicy.txt /v > "C:\ProgramData\$GPOName $GPOVersion User.log"
"@ | Out-File -Encoding ascii "$DownloadLocation\LGPOExecute.bat" -Force
     
    }
}
catch {
    write-host "The download and extraction of LGPO.EXE failed. Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
write-host "Clearing all existing policies." -ForegroundColor Green
#Clears all local policies
remove-item -Recurse -Path "$($ENV:windir)\System32\GroupPolicyUsers" -Force -erroraction silentlycontinue
remove-item -Recurse -Path "$($ENV:windir)\System32\GroupPolicy" -Force -erroraction silentlycontinue
remove-item -Recurse -Path "$DownloadLocation\ComputerPolicy.txt" -Force -erroraction silentlycontinue
remove-item -Recurse -Path "$DownloadLocation\Userpolicy.txt" -Force -erroraction silentlycontinue
write-host "Running GPUpdate to clear local policy cache." -ForegroundColor Green
gpupdate /force
write-host "Starting GPEdit. Please create your policy. After closing GPEdit we will resume." -ForegroundColor Green
start-process "gpedit.msc" -Wait
write-host "Exporting policies with LGPO." -ForegroundColor Green
& "$DownloadLocation\LGPO.EXE" /parse /m "$($ENV:windir)\System32\GroupPolicy\Machine\Registry.pol" > $DownloadLocation\ComputerPolicy.txt
& "$DownloadLocation\LGPO.EXE"  /parse /u "$($ENV:windir)\System32\GroupPolicy\User\Registry.pol" > $DownloadLocation\Userpolicy.txt
write-host "Sleeping for 10 seconds to give LGPO a chance to export all settings if GPO is large." -ForegroundColor Green
start-sleep 10
$UserDesktop = [Environment]::GetFolderPath("Desktop")
@"
Setup=LGPOExecute.bat
TempMode
Silent=1
"@ | out-file "$DownloadLocation\SFXConfig.conf" -Force
 
write-host "Creating Apply executable and placing on current user desktop." -ForegroundColor Green
& $WinrarPath -s a -ep1 -r -o+ -dh -ibck -sfx  -iadm -z"C:\temp\LGPO\SFXConfig.conf" "$UserDesktop\$GPOName $GPOVersion Apply Policy.exe" "$DownloadLocation\*"
start-sleep 3
 
write-host "Creating Remove executable and placing on current user desktop." -ForegroundColor Green
$ComputerPolicy = get-content "$DownloadLocation\ComputerPolicy.txt"
$UserPolicy = get-content "$DownloadLocation\UserPolicy.txt"
$ReplacementArray = @("DELETEKEYS", "DELETE", "QWORD", "SZ", "EXSZ", "MULTISZ", "BINARY", "CREATEKEY", "DELETEALLVALUES", "DWORD")
foreach ($Replacement in $ReplacementArray) {
    $ComputerPolicy = $ComputerPolicy | Foreach-Object { $_ -replace "^.*$replacement.*$", "CLEAR" }
    $UserPolicy = $UserPolicy | Foreach-Object { $_ -replace "^.*$replacement.*$", "CLEAR" }
}
$UserPolicy | out-file "$DownloadLocation\Userpolicy.txt"
$ComputerPolicy | out-file "$DownloadLocation\ComputerPolicy.txt"
 
& $winrarPath -s a -ep1 -r -o+ -dh -ibck -sfx  -iadm -z"C:\temp\LGPO\SFXConfig.conf" "$UserDesktop\$GPOName $GPOVersion Remove Policy.exe" "$DownloadLocation\*"
remove-item -Recurse -Path "$DownloadLocation\LGPOExecute.bat" -Force -erroraction silentlycontinue