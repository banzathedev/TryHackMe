Store 	What It Holds 	Why It Exists 	Access Method 	Tools & Commands
LSASS Memory 	NTLM hashes, Kerberos tickets, cleartext (sometimes) 	Enables seamless logon across services 	Dump live memory of lsass.exe 	mimikatz
sekurlsa::logonpasswords
sekurlsa::minidump
SAM + SYSTEM Hives 	Local account hashes 	Authentication for local logons (e.g. local admin) 	Export registry hives, extract with boot key 	mimikatz
lsadump::sam
vssadmin to extract
LSA Secrets 	Cached domain creds, plaintext service creds 	Enables offline logon, stores scheduled task passwords, and RDP secrets 	RPC via LSARPC named pipe 	secretsdump.py with local admin creds
DPAPI Vault 	Saved passwords from apps (RDP, browsers, WiFi) 	User-level secure storage for creds 	Access via user token or decrypted master key 	mimikatz
vault::list
vault::cred /export to extract
NTDS.dit (DC only) 	Full domain DB: usernames, NTLM & Kerberos keys 	Domain authentication and replication 	Replicate over MS-DRSR or parse an offline file 	
secretsdump.py -just-dc
lsadump::dcsync

the table above show the places, what stores and how to acess, all about ad credentials harvesting. 

task 3 

Pratical exercise 

objective use mimikaty to extract credentials, to allow lateral movement or privileage escalation, the main objective is land an shell with adiministration privilages on domain controller.

we are given local adiminitrator account, so we can supose in a normal attack chain we aready stabilsh first contact, gather information or credentials, an was lucky enought to find local admin acc and also be capable to 
Install mimikatz on the workstation. 

we start by opening the mimikatz tool, remembering that DPAPI uses user password to encrypt information, in the user context we can decrypt information stored in there, like wifi, RDP and apps passwords. 

looking into the image bellow, we se there are two vaults, one web and one for windows credentials 
the second on contain one item that we can export, lets try it. 


as we can see in the image we sucessfully extracted some credentials. 


With HIVES SAM + SYSTEM, we can extract the registry from sam were all users NTLM Hashes are stored, then we need the key stored in SYS hive that also is possible to get since we have local admin privs. 

then we can use mimikatz to extract the NTLM Hashes, that open possibility to crack offline or use on pass-the-hash attacks. 

its 3 commands that we are going to use 

retreive SAM = reg save HKLM\SAM C:\Users\Administrator\Desktop\SAM 
retreive HIVE = reg save HKLM\SYSTEM C:\Users\Administrator\Desktop\SYSTEM

NOTE: this two commands above should be ran in an normal CMD/terminal. 


we successfully extracted the registry that are needed, as the image shows. 

now we are going to use mimikatz to decrypt 

simple enought we got the hashes stored. 


the next part is a bit more dificult. 

to access lsa memory(lsass.exe) we need admin powers and  often system level priv to access 
and special tools to decrypt. 

using 


        

    privilege::debug: Enables the SeDebugPrivilege for mimikatz to read and manipulate process memory (required for LSASS dumps).
    sekurlsa::logonpasswords: Reads credential structures from LSASS memory. Expected output: A dump of all current user sessions, including usernames, domains, NTLM/SHA1 hashes, and any plaintext passwords found in memory.

lets see

yeah it got some credentials, service acc creds, users creds.



We don't get any domain user credentials because they currently don't have any active sessions on WRK; therefore, LSASS memory no longer retains them, even if they logged in previously.

LSA Secrets 

owever, if we elevate our token to System, we can use lsadump::cache to extract cached domain credentials on WRK. We will use secretsdump.py in the next task to achieve this. 

as show in the image bellow we need to elevate our token to sytem before dump the lsa cache. 

Task 04 pratical exercises

lets talk about secretsdump.py 

In Active Directory environments, secrets are often accessible remotely through native Windows services. Secretsdump.py from the Impacket suite allows us to extract those secrets over using SMB OR DCE/RPC. This tool lets you pull local hashes, LSA secrets, and even full domain credentials, depending on the privileges of the account used.

This technique is valuable because it does not require uploading binaries or touching sensitive files directly. Instead, it uses built-in Windows functionality to retrieve credential material stealthily and remotely. In the previous task, we managed to get some domain user credentials, but not any domain admins.

since is an impackets script an i have install my machine we can call direct from our machine widouth need to upload or install any program in the machine. 


LETS SEE IN ACTION ON IMAGE BELLOW 


We are interested in MS-Cache v2 (aka DCC2) password hashes. DCC2 hashes are Domain Cached Credentials stored locally on Windows machines. They allow users to log in to a domain account offline, such as on a laptop not currently connected to the domain network. As a local admin, we can dump a domain admin's hashes if they've logged into a system before.

Unlike NTLM hashes, we cannot use DCC2 hashes for pass-the-hash attacks. However, we can use them to crack offline passwords

all have beein dumped fine, then i used hashcat to cyper the hashes dc2 find. 

then dump againg but this time as domain admin as the image shows. 

then we can user psexec an pass admin ntlm hash to execute an gain shell, then go to the desktop to retreive shell. 
