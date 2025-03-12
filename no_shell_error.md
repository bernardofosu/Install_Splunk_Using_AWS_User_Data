It looks like you're trying to switch to the splunkfwd user using su splunkfwd, but nothing happens—meaning you might not have a shell assigned to that user.

Try checking the user's shell by running:
```sh
getent passwd splunkfwd
```
This will output something like:
```sh
splunkfwd:x:1001:1001::/home/splunkfwd:/usr/sbin/nologin
```
If the shell is set to /usr/sbin/nologin or /bin/false, then the user is not allowed to log in interactively.
🔧 Fix:

If you want splunkfwd to have a shell, change it to /bin/bash:
```sh
sudo usermod -s /bin/bash splunkfwd
```
Then, try switching again:
```sh
su - splunkfwd
sudo su - splunkfwd
```