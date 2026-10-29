#DNS
$dcIPAddress = "192.168.10.110"

echo "Pointing DNS"
$adapters = Get-WmiObject Win32_NetworkAdapterConfiguration
if ($adapters) {
    $adapters | ForEach-Object {$_.SetDNSServerSearchOrder($dcIPAddress)}
}

#Credentials
$domainAdministratorPassword = "childdomainftw1!"
$domainNetbiosName = "tbm.thm.loc"

$securePassword = ConvertTo-SecureString $domainAdministratorPassword -AsPlainText -Force
$username = $domainNetbiosName + "\Administrator" 
$domainAdminCredentials = New-Object System.Management.Automation.PSCredential($username, $securePassword)

#Domain Joining
echo "Joining computer"
Add-Computer -DomainName $domainNetbiosName -Credential $domainAdminCredentials
echo "Computer Joined"
    
