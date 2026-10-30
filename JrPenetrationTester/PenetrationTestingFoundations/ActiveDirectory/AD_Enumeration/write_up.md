on this room 

we are going to try enumerate an AD having only an ip mask. 

starting with fping we found 4 alive hosts 

10.211.11.1
10.211.11.10
10.211.11.20
10.211.11.250

the first beeing the gatway and last vpn, only the middle ones are relevant for us. 

the we are going to use nmap to gaing deeper information on this two hosts.

on nmap_port_specific_scan.txt you can see the output 

but the relevant information is 

Domain name: tryhackme.loc

smb-os-discovery: 
|   OS: Windows Server 2019 Datacenter 17763 (Windows Server 2019 Datacenter 6.3)

and ports 88,135,139,389,445,636 are open. 


task3 

pratical exercises 

we are going to enumerate with SMB 

the main tools that are going to be used are, Nmap, SMBClient, SMBMap. 

lets start 

we are mainly interest to MS systems and AD related ports, so our scan are going to be limited to relevant ports 
but in an real scenario probe all ports could generated more leads, clues and relevant information. 

as show in the picture the open ports tell us this is an MS AD enviroment, the kerberos and ldap indicates that the host is potentialy  Active Directory domain or even a domain controller.

since we dont have yet credentials, lets check the expose SMB and see if anonymous connection is allowed(also know as null session) 

for this THM indicates that from linux based systems are two good tools available SMBClient and SMBMap, lets use it!

we used -L flag to list all shares and -N to try connect anonymously, as we can see above, we receive an list of interesting shares. 

now lets use SMBMap, on thm attackbox is an .py script  located at /Desktop/Tools/Miscellaneous/smbmap#  and is used  ./smbmap.py 
in my case i opt to download from ubuntu repository and run directily from cli. 

SMBMap is a good tool to quick check SMB shares missconfigured, check for read and write permissions widhout connect. 

as showned the image above we can see somw shares that we can read or write, an this is an potetial way to secure access to an workstation or user. 

using nmap to discover SMB Shares is also possible, by using the following scritp nmap -p445 --script smb-enum-shares

important to mention that nmap includes a ton of scripts(NSE Scripts) that are used for multiple cases, including but not only, discover potential vulnerabilyties and shares and so on. 

so using SMBCLient lets start looking into the shares that are readble from null session, using the following command smbclient //TARGET_IP/SHARE_NAME -N 

we are doing this way because we dont have any credentials, but in case we had  it could be used and potentialy give us more access to other shares. 

on SharedFiles we found an archive.txt as on the image above. 

then on UserBackups as show in the image we found an flag. 

task 4 

pratical exercises 

know we are going to try get an user. 

first we will try LDAP ENumeration(ANonymous bind) 

since some ldap can be configured or better saying misconfigured to allow anonymous queries(read only) this can be an way to search for users to crack on. 

using ldapsearch tool we are going to verify if our host ldap allows. 

command 
ldapsearch -x -H ldap://10.211.11.10 -s base 
 
breakdown
-x: Simple authentication, in our case, anonymous authentication.
-H: Specifies the LDAP server.
-s: Limits the query only to the base object and does not search subtrees or children.

the first result well be available on ldapsearch_result_all.txt since is to big 

than using the following command we can search for users ldapsearch -x -H ldap://10.211.11.10 -b "dc=tryhackme,dc=loc" "(objectClass=person)" 
not that within the domain controller(dc) we ask for the objectClass person, this is the way that Active directories classify persons/users. 

we receive a list, againg to long to display here, so will be available on ldapsearch_users_result.txt


but we got some interest results 

some users from departments like, HR, SALES, Consulting, Marketing an sutch reveal an possible pattern for users. 
eg: jennifer.harding
possible pattern first.last 
matching 

althoug there is an deveant user rduke, not consting any departament, i will asume that the pattern is first.last. 

other tools that could be very use are enum4linux-ng  and rpcclient

as show in the image above with rpcclient we also can enumerate users. 

quoting THM since i cant describe better
 In Active Directory, RID (Relative Identifier) ranges are used to assign unique identifiers to user and group objects. These RIDs are components of the Security Identifier (SID), which uniquely identifies each object within a domain. Certain RIDs are well-known and standardised.

500 is the Administrator account, 501 is the Guest account and 512-514 are for the following groups: Domain Admins, Domain users and Domain guests. User accounts typically start from RID 1000 onwards.

We can use enum4linux-ng to determine the RID range, or we can start with a known range, for example, 1000-1200, and increment if we get results.

If enumdomusers is restricted, we can manually try querying each individual user RID with this bash command:

for i in $(seq 500 2000); do echo "queryuser $i" |rpcclient -U "" -N 10.211.11.10 2>/dev/null | grep -i "User Name";

this command couldtake up 3 minutes to complete. 

task 5 

Pratical exercise 

password spraying, before start since we have rdpclient session null, we could check for the passwords policy to enhence our spray. 

using the getdompwinfo we can acheive that. 

THM says to use CrackMapExec, but the tool is outdated, NetExec/nxc is its sucessor, since im using my own machine i will be using netexec. 


as the image above shows, this is the password policy.


    In rpcclient: password_properties: 0x00000001
    With NetEXec: Password Complexity Flags: 000001

This means that at least three of the following four conditions need to be respected for a password to be created:

    Uppercase letters
    Lowercase letters
    Digits
    Special characters

Also, passwords cannot contain the user's account name or parts of their full name exceeding two consecutive characters. We can refer to this link to understand Microsoft's password complexity definitions.


Let's imagine that through some OSINT, we discovered that this company was in a data breach, and some of the known passwords were variations of the string "Password". We can create the following list, making sure to respect the password policy:

    Password!
    Password1
    Password1!
    P@ssword
    Pa55word1


using nxc e found that rduke:Password1! 
