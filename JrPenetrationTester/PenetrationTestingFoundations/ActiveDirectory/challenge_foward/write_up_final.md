Active Directory CTF — Write-up
Introduction

In this room, the challenge is based on lateral movement and privilege escalation until we eventually reach SYSTEM-level access.

Credentials are provided at the beginning of the challenge:

text
USER: ctf.local\j.smith
PASS: JSmith@IT2024


Since I'm working from my own machine, the first thing I do is add the target IP address and domain to /etc/hosts.

I also export the target IP address as $ip to make things easier throughout the process.

1. Initial Reconnaissance

Before running Nmap and starting the reconnaissance phase, we can already make a few assumptions about the Active Directory environment.

Based on the provided username (j.smith), we can assume that the organization probably follows a username convention based on the first initial and last name.

The password also gives us a potential pattern:

text
@DepartmentXXXX


Where XXXX represents a year.

This information can be useful later during user enumeration and password spraying.

Nmap Scan

I start by running Nmap with the following flags:

-sV: Service version detection.
-sC: Run default NSE scripts.
-Pn: Disable host discovery and treat the target as online.

The complete output from the scan can be found in nmap_result.txt.

!Nmap Scan Results

You can also run a more aggressive scan using -T4 or -T5. However, faster scans generate more traffic and may trigger security monitoring or be blocked. They are not recommended against real-world environments without authorization.

BloodHound Enumeration

Knowing that we're dealing with an Active Directory environment, the next logical step is to use BloodHound Python to collect additional information about the domain.

The collection revealed that the environment contains only one computer: DC01.

From this point onwards, we can assume that most of our lateral movement will happen between accounts and privileges within the same domain controller, rather than between multiple machines.

The collected data is available in the generated .zip file.

!BloodHound Collection

Collection summary:

text
INFO: Found 1 domains
INFO: Found 1 computers
INFO: Found 8 users
INFO: Found 54 groups


There wasn't much to discover through BloodHound's web interface at this stage, but we still gathered some valuable information.

2. Initial Access and KeePass Discovery

The next logical step is to connect via RDP using the credentials kindly provided by the challenge.

While exploring the machine, I came across something interesting: KeePass.

!KeePass Discovery

I tried searching for additional information, but KeePass was the only relevant discovery.

At the time, I wasn't familiar with this application, so I looked it up and discovered that it is a password manager.

Since this was the only unusual thing I found during my initial exploration, I suspected it might be a clue.

!KeePass Application

After investigating further, I managed to obtain another set of credentials:

text
User: t.jones
Pass: Helpd[REDACT]

BloodHound Analysis

I used the newly discovered account to gather more information about its relationships within Active Directory.

!T. Jones BloodHound Relations

The image above shows t.jones and its relationships within the domain.

I also ran a few additional tests using NetExec to gather more information about the environment.

!NetExec Tests

After that, I connected via RDP using the new account and explored the machine, but nothing particularly relevant came up.

3. Password Policy Enumeration

The next thing I checked was the domain password policy.

This information is particularly useful when planning password-related enumeration and testing.

!Password Requirements

The relevant output was:

text
min_password_length: 7
password_properties: 0x00000001
    DOMAIN_PASSWORD_COMPLEX


So, what does this actually mean?

Let's break it down.

Password Properties

password_properties: 0x00000001 is a bitmask indicating that password complexity enforcement is enabled on the domain.

DOMAIN_PASSWORD_COMPLEX means that passwords must follow the standard Active Directory complexity requirements.

These include:

Passwords cannot contain the user's account name (sAMAccountName) or significant parts of their display name.
Passwords must contain characters from at least three of the following five categories:
Uppercase letters (A-Z).
Lowercase letters (a-z).
Base-10 digits (0-9).
Special characters (!, @, #, $, %, etc.).
Unicode characters that do not belong to the previous categories.

The minimum password length is also set to seven characters.

This gives us a better understanding of the password policy and helps narrow down potential password patterns.

4. User Enumeration and Password Spraying

Now we know at least two passwords and have a better understanding of the domain's password requirements.

The next thing we need is more users.

For this, we can use RID brute force enumeration.

One interesting thing about this technique is that we only need one valid domain session to enumerate additional users. The account doesn't necessarily need administrative privileges.

RID Brute Force

After running RID brute force, we managed to discover additional users.

!RID Brute Force Results

Fantastic! We found r.williams.

Earlier, I had already noticed this username while exploring the machine, but I didn't have access to the user's files.

!R. Williams User Discovery

However, I noticed a .txt file on the user's desktop that could potentially contain useful information.

!Automation Notice

Let's take a look at its contents:

text
HelpDesk Automation Notice
==========================

A background process handles automatic ticket processing and
service account maintenance for the HelpDesk system.

The automation runs periodically and stores temporary working
files in C:\Windows\Temp.

Contact the sysadmin team if you notice any issues.
-- IT Operations


Interesting.

This suggests that there might be some automated process running in the background, potentially involving a service account.

Definitely something worth keeping in mind for privilege escalation.

Checking the Account Lockout Policy

Before doing any password testing, I decided to check whether account lockout was enabled.

!Account Lockout Policy

To my surprise, the domain did not appear to enforce an account lockout policy.

This is an important finding because it means that repeated failed authentication attempts are not subject to the usual domain account lockout threshold.

Keep in mind that the absence of an account lockout policy does not necessarily mean there are no other rate-limiting or monitoring mechanisms.

Password Reuse

Remember the password complexity requirements we discovered earlier?

Something caught my attention: even though password complexity is enabled, nothing in the policy indicates that users must have unique passwords.

In other words, password reuse is still possible.

Since we already have two valid passwords, I decided to check whether other users were reusing them.

First, I created a clean list of domain users.

!User List

Then, I created a list containing the two passwords we had already discovered.

!Password List

And there we go!

Both t.jones and r.williams were using the same password.

This is a good example of why password reuse is worth investigating during an authorized Active Directory assessment.

5. Exploring R. Williams' Account

Now that we have access to another account, let's connect via RDP and investigate the files we found earlier.

Note: I'm using RDP mainly for visual exploration. Other remote access methods may also be available, depending on which services are enabled and configured on the machine.

Remember the automation notice?

It mentioned a background process responsible for HelpDesk automation and service account maintenance.

This could be relevant to our privilege escalation path.

BloodHound: Resource-Based Constrained Delegation

Going back to BloodHound, I noticed an interesting relationship involving r.williams.

!Allow To Act Relationship

The relationship indicates that r.williams has permission to modify the msDS-AllowedToActOnBehalfOfOtherIdentity attribute on the DC01$ computer object.

So, what does this mean?

This permission is associated with Resource-Based Constrained Delegation (RBCD).

In simple terms, RBCD allows a computer account to specify which other accounts are trusted to impersonate users when accessing services on its behalf.

In this scenario, controlling the delegation attribute on DC01$ means that we may be able to authorize a computer account under our control to impersonate other domain users when accessing services on the domain controller.

This can be abused through the Kerberos S4U extensions:

S4U2Self: Allows a service to obtain a service ticket on behalf of a user.
S4U2Proxy: Allows a service to obtain a ticket to another service on behalf of that user, subject to delegation restrictions.

There is one more important detail.

We don't currently control a computer account.

However, Active Directory has a setting called ms-DS-MachineAccountQuota, which, when configured with its default value, allows regular domain users to create up to ten computer accounts.

This gives us a potential path to abuse RBCD.

Let's put this together.

Abusing RBCD

!Rogue Computer Account

The idea is to use the available permissions to establish a computer account under our control and leverage the delegation configuration on DC01$.

Important note: Kerberos is very strict about time synchronization.

Before requesting Kerberos tickets, make sure your machine's clock is synchronized with the domain controller. Otherwise, authentication may fail because of clock skew.

After setting everything up, we can proceed with the Kerberos ticket request and use the resulting ticket to authenticate to the target.

6. Final Access

After obtaining the required Kerberos ticket, I used it to authenticate to the domain controller.

!Connecting to DC01

And we're in!

The final flag is located on the Desktop.

At this point, we've successfully completed the privilege escalation path and reached the highest privilege level required by the challenge.

Conclusion

This room was a good example of how small misconfigurations and overlooked Active Directory permissions can be chained together to achieve privilege escalation.

The interesting part wasn't a single vulnerability, but rather how multiple pieces of information eventually connected.

We started with a regular domain account, enumerated users, discovered password reuse, and eventually identified an RBCD misconfiguration that allowed us to escalate privileges.

Key Takeaways

Here are the main things worth remembering from this challenge:

1. Information Gathering Matters

Even small details, such as username conventions and password patterns, can become valuable during an assessment.

Don't overlook information provided at the beginning of a challenge.

2. BloodHound Is Your Friend

BloodHound is extremely useful for understanding relationships and permissions within Active Directory.

Even when the initial graph looks empty, interesting attack paths may become visible after obtaining additional accounts.

3. Password Complexity Doesn't Prevent Password Reuse

A strong password policy doesn't necessarily mean that users have strong or unique passwords.

Password reuse can expose multiple accounts even when complexity requirements are enforced.

4. Always Check the Account Lockout Policy

Understanding the domain's password and account lockout policies is important when assessing authentication security.

Misconfigured policies can increase the risk of password-based attacks.

5. Pay Attention to Unusual Files and Applications

The KeePass discovery and the HelpDesk automation notice were small clues that helped guide further investigation.

Sometimes, the most interesting findings are not immediately obvious.

6. Understand RBCD

Resource-Based Constrained Delegation is a powerful Active Directory feature that can become a privilege escalation vector when its permissions are misconfigured.

Always pay attention to relationships involving:

msDS-AllowedToActOnBehalfOfOtherIdentity
Computer accounts.
Delegation permissions.
ms-DS-MachineAccountQuota.
7. Kerberos Time Synchronization Is Important

Kerberos authentication depends on time synchronization.

If your clock is out of sync with the domain controller, ticket requests and authentication may fail.

Final thoughts:

The biggest lesson from this room is that Active Directory security is all about relationships, permissions, and trust.

A regular user might not look dangerous at first, but when combined with password reuse, excessive permissions, and delegation misconfigurations, that account can become the starting point for a complete domain compromise.

Always enumerate, investigate, and connect the dots.
