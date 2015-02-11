<#
.SYNOPSIS
Install-MFLicense will install the MicroFocus license service on a machine or group of machines.

.INPUTS
None.

.OUTPUTS
A log file are created on the F: drive of the script actions.

.EXAMPLES
.\Install-MFLicense.ps1
#>

#Set the log file location:
$LogLocation = "F:\MFLicenseInstall.txt"

#Create a directory to contain the MF installer files:
New-Item -ItemType Directory -Path "F:\MFLicense-Extract" | Out-Null
if ($?)
{
    Add-Content $LogLocation "MF directory created"
}
else
{
    Add-Content $LogLocation "ERROR: Could not create MF directory!"
    exit
}

#Copy the MF installer files from the file share to the directory just created:
Copy-Item -Path "\\path.to.your\SoftwareShare\MicroFocusLicense\*" -Destination "F:\MFLicense-Extract"
if ($?)
{
    Add-Content $LogLocation "MF installer files copied"
}
else
{
    Add-Content $LogLocation "ERROR: MF installer files could not be copied!"
    exit
}

#Try to rename the existing COBOL source files for backup:
try
{
    $ASCIIBak = Get-ChildItem "$env:PS_HOME\src\cbl\win32\ASCII.BAK" -ErrorAction SilentlyContinue
    if ($ASCIIBak -ne $null)
    {
        Remove-Item "$env:PS_HOME\src\cbl\win32\ASCII.BAK" -Force
    }
    $EBCDICBak = Get-ChildItem "$env:PS_HOME\src\cbl\win32\EBCDIC.BAK" -ErrorAction SilentlyContinue
    if ($EBCDICBak -ne $null)
    {
        Remove-Item "$env:PS_HOME\src\cbl\win32\EBCDIC.BAK" -Force
    }
    $ASCIIDir = Get-ChildItem "$env:PS_HOME\src\cbl\win32\ASCII.DIR" -ErrorAction SilentlyContinue
    if ($ASCIIDir -ne $null)
    {
        Rename-Item -Path "$env:PS_HOME\src\cbl\win32\ASCII.DIR" -NewName "ASCII.BAK" -Force
    }
    $EBCDICDir = Get-ChildItem "$env:PS_HOME\src\cbl\win32\EBCDIC.DIR" -ErrorAction SilentlyContinue
    if ($EBCDICDir -ne $null)
    {
        Rename-Item -Path "$env:PS_HOME\src\cbl\win32\EBCDIC.DIR" -NewName "EBCDIC.BAK" -Force
    }
    Add-Content $LogLocation "COBOL source files renamed"
}
catch
{
    Add-Content $LogLocation "ERROR: Could not rename COBOL source files!"
    exit
}

#Copy the installer COBOL source files over the ones that were backed up:
Copy-Item -Path "F:\MFLicense-Extract\*.DIR" -Destination "$env:PS_HOME\src\cbl\win32\" -Force
if ($?)
{
    Add-Content $LogLocation "COBOL source files copied to directory"
}
else
{
    Add-Content $LogLocation "ERROR: Could not copy COBOL source files!"
    exit
}

Set-Location "F:\MFLicense-Extract"
#Call the batch file to set up the installation process and save its output to the log:
.\setupMF.bat
Add-Content $LogLocation "Setting up MF environment..."

#Start the MF license installer:
.\MFLMWin.exe -i
Add-Content $LogLocation "Starting MF installer..."
Remove-Item Install-MFLicense.ps1 -Force
