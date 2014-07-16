<#
.SYNOPSIS
Install-WebLogic will silently install the Oracle WebLogic server on a machine.

.INPUTS
None - the script contains all information required to run.

.OUTPUTS
Messages are printed to the console as the installation progresses.  A log file is created of the installation.

.EXAMPLES
.\Install-WebLogic.ps1

.NOTES
The location where the installer files and answer files are located must be accessible over the network on the machine
where WebLogic is to be installed.
#>

#Set the location of the installer and the answer file:
$InstallerLocation = "\\path.to.your\SoftwareShare\WebLogic"

#Map a network drive for the copyover of the installer to the local system:
New-PSDrive -Name "X" -PSProvider FileSystem -Root $InstallerLocation | Out-Null
#Copy the installer and answer files to the local system:
Copy-Item -Path "X:\weblogic.jar" -Destination "F:\weblogic.jar"
Copy-Item -Path "X:\silent.xml" -Destination "F:\silent.xml"
#Change to the location of the installer files:
Set-Location $env:JAVA_HOME\bin
#Call the Java executable to install WebLogic silently using the answer file, writing a log of the install:
.\java.exe -Xmx1024m -jar F:\weblogic.jar -mode=silent -silent_xml=F:\silent.xml -log=F:\WebLogicInstall.log
#Remove the installer and answer file to reclaim drive space:
Remove-Item "F:\weblogic.jar"
Remove-Item "F:\silent.xml"
