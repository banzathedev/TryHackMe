#DNS
$parentdcIPAddress = "192.168.10.100"

echo 'Configuring DNS...'
$adapters = Get-WmiObject Win32_NetworkAdapterConfiguration
if ($adapters) {
    $adapters | ForEach-Object {$_.SetDNSServerSearchOrder($parentdcIPAddress)}
}

#Password Reset
$domainAdministratorPassword = "childdomainftw1!"
$domainSafeModeAdministratorPassword = "childdomainftw1!"

echo 'Resetting the Administrator account password and settings...'
$localAdminPassword = ConvertTo-SecureString $domainAdministratorPassword -AsPlainText -Force
Set-LocalUser `
    -Name Administrator `
    -AccountNeverExpires `
    -Password $localAdminPassword `
    -PasswordNeverExpires:$true `
    -UserMayChangePassword:$true

$safeModePassword = ConvertTo-SecureString $domainSafeModeAdministratorPassword -AsPlainText -Force

#Parent Domain Credentials
$parentAdministratorPassword = "learningadisfun1!"
$parentName = "THM.LOC"

$parentPassword = ConvertTo-SecureString $parentAdministratorPassword -AsPlainText -Force
$parentDA =  $parentName + "\Administrator" 

echo 'Configuring the parent domain credentials'
$parentCredentials = New-Object System.Management.Automation.PSCredential($parentDA, $parentPassword)

#Tool Installation
echo 'Installing the AD services and administration tools...'
#Install-WindowsFeature AD-Domain-Services,RSAT-AD-AdminCenter,RSAT-ADDS-Tools

#Promoting to DC
$domainName = "tbm"
$domainNetbiosName = "TBM"
$parentFqdn = "thm.loc"

echo 'Installing the AD domain (be patient, this will take more than 5m to install)...'

Import-Module ADDSDeployment
Install-ADDSDomain `
    -Credential $parentCredentials `
    -NewDomainName $domainName `
    -SafeModeAdministratorPassword $safeModePassword `
    -CreateDnsDelegation:$true `
    -DatabasePath "C:\Windows\NTDS" `
    -DomainMode "6" `
    -NewDomainNetbiosName $domainNetbiosName `
    -InstallDns:$true `
    -NoRebootOnCompletion:$true `
    -Force:$true `
    -ParentDomainName $parentFqdn

echo 'Promotion complete! Restart required!'
    
