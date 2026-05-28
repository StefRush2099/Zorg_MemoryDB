# Beginner Terminal and SSH Basics

Use this page before the install or upgrade pages if the terminal is new to you.

Official basis:

OpenClaw install guide: https://docs.openclaw.ai/install

OpenClaw TUI guide: https://docs.openclaw.ai/cli/tui

Ubuntu SSH guide: https://help.ubuntu.com/community/SSH/OpenSSH/ConnectingTo

## What the Terminal Is

The terminal is a text box for giving instructions to a computer. Instead of clicking buttons, you paste or type a command and press Enter.

Commands in these docs are shown in boxes like this:
```bash pwd ```

You do not type the word `bash`. It only tells the documentation system that the command is meant for a Linux/Ubuntu terminal.

## What SSH Is

SSH is how you open a terminal on a different computer over the network.

If OpenClaw/Zorg MemoryDB is being installed on a remote Ubuntu server, first connect to that server from your own computer:
```bash ssh stefan@192.168.1.50 ```

What this means:

`ssh` starts a secure terminal connection.

`stefan` is the Ubuntu username on the server. Use your own server username.

`192.168.1.50` is an example server IP address. Use the real IP address of your Ubuntu server.

After login, every command you type runs on the Ubuntu server, not on your laptop.

If you are sitting directly at the Ubuntu computer, you do not need SSH. Open the Terminal app on that computer instead.

## What Paths Mean

A path is the address of a folder or file.

Examples:

`~/front-desk-assistant` means a folder named `front-desk-assistant` inside your home folder.

`/opt/stacks/front-desk-assistant` means a folder under `/opt/stacks`, which is a common Dockge stack location.

`./openclaw-home` means a folder named `openclaw-home` inside the folder you are currently in.

The slash character `/` separates folder names. Do not replace it with a backslash.

## Commands You Will See

```bash cd ~/front-desk-assistant ```

What this does: `cd` means change directory. It moves the terminal into the `front-desk-assistant` folder so the next command runs in the right place.
```bash pwd ```

What this does: prints the folder you are currently in.
```bash ls ```

What this does: lists files and folders in the current folder.
```bash sudo apt-get update ```

What this does: `sudo` asks Ubuntu to run the command with administrator permission. Ubuntu may ask for your password.
```bash git clone https://github.com/StefRush2099/Zorg_MemoryDB.git front-desk-assistant ```

What this does: downloads the Zorg MemoryDB project from GitHub and creates a local folder named `front-desk-assistant`. The final words are the folder name you will see later.
```bash docker compose up -d --build ```

What this does: asks Docker Compose to build and start the assistant in the background.

If Docker says you do not have permission, the command may need to start with `sudo`, like `sudo docker compose up -d --build`. Some install pages avoid that by adding your Ubuntu user to the Docker group; Dockge and `/opt/stacks` examples use `sudo` more often because those folders are commonly administrator-managed.

## Read Command Blocks One Line at a Time

When a command box has several lines, run them in order from top to bottom. Do not skip lines unless the page explicitly says they are optional.

If a command begins with `#`, it is a comment for humans and does not need to be pasted.

## Stop Before Deleting

If a command contains `rm`, `delete`, `prune`, `reset`, or says it removes a folder, stop and make sure the page says it is safe. The folder named `openclaw-home/` is the important state folder for Docker-based installs and should not be deleted during normal upgrades.
