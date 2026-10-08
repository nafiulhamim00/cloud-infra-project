# Lab 9: Getting Started with Docker: Deploying a Basic Web App

## Table of Contents

- [Table of Contents](#table-of-contents)
- [Learning Objectives](#learning-objectives)
  - [Note](#note)
- [Task 1 - Prepare Virtual Machine on UiS Cloud](#task-1--prepare-virtual-machine-on-uis-cloud)
- [Task 2 - Install Docker](#task-2--install-docker)
- [Task 3 - Container Lifecycle and Ports](#task-3--container-lifecycle-and-ports)
- [Task 4 - Configuration, Persistence, and Debugging](#task-4--configuration-persistence-and-debugging)
- [Next Steps](#next-steps)

## Learning Objectives

- **Duration:** ~90 minutes
- **Prerequisites:** Access to UiS campus network

By the end of this part, you will be able to:

- Set up and configure a virtual machine on UiS Cloud (OpenStack)
- Install and configure Docker, including the OpenStack MTU fix
- Manage the container lifecycle: run, inspect, log, exec, stop, and remove
- Persist data with named volumes and debug a container that refuses to start

### Note

You may skip the VM setup and complete this lab on your own machine instead.
The easiest way to do this is to install [Docker Desktop](https://www.docker.com/products/docker-desktop/) (Windows/WSL2, macOS, Linux) and make sure it has enough memory and CPU allocated.
If you do this, skip to Task 2.

## Task 1 - Prepare Virtual Machine on UiS Cloud

**Note that certain parts of this lab require UiS campus network access.**

1. **Login to UiS's OpenStack**

   Login to [cloud.cs.ux.uis.no/horizon](https://cloud.cs.ux.uis.no/horizon) using your GitHub username as both the username and password.

2. **Network**

   Use existing network in your project called dat515-network.

3. **Security Configuration:**

   **Manage Security Group Rules:**

   - Navigate to `Project->Network->Security Groups`
   - Select Manage Rules, and click `+ Add Rule`
   - Select SSH from the Rule dropdown menu
   - In the CIDR field, enter the IP address from where you want to connect
     For example, to grant access to the whole university network: `152.94.0.0/16`
   - Click Add

4. **SSH Key Management**

   - **Note:** We have already uploaded the SSH key you provided when creating your account on `sshvm.cs.ux.uis.no` and OpenStack account in [1unix](../../1unix/README.md) lab. If you plan to use the same SSH key, you can skip this step.

   **Option 1 - Import Existing SSH Key**

   - Navigate to `Project->Compute->Key Pairs`
   - This assumes you have already generated an SSH key pair on your local machine
   - Reference: [Generate SSH keys](https://romanzolotarev.com/ssh.html)
   - Click `+ Import Public Key`
   - Enter Key Pair Name
   - Select SSH Key from the Key Type dropdown menu
   - Choose File or Paste your SSH public key in the Public Key field
   - Click Import Public Key

   **Option 2 - Create New Key Pair**

   - Navigate to `Project->Compute->Key Pairs`
   - Click `+ Create Key Pair`
   - Enter Key Pair Name
   - Select SSH Key from the Key Type dropdown menu
   - Click Create Key Pair
   - This will download the private key file; move this to your `.ssh` directory

5. **Create Virtual Machine Instance**

   - Navigate to `Project->Compute->Instances`
   - Click Launch Instance
   - Enter Instance Name
   - **Source:** Pick a VM Image (e.g., Ubuntu 24.04) from Available section
   - **Flavor:** Pick a Flavor (e.g., m1.large) from Available section
   - **Key Pair:** Pick the Key Pair you created or imported earlier
   - **Networks and Security Groups:** Should be configured correctly from previous steps
   - Click Launch Instance

6. **Network Access Configuration - Associate Floating IP**

   - Still on the `Project->Compute->Instances` page
   - Floating IP (public IPv4) is required for external access
   - Click the Down arrow on the right side of the Create Snapshot button
   - Select Associate Floating IP from the dropdown menu
   - Click the + button to create a new floating IP Address (first time only)
   - Click Allocate IP
   - Click Associate

7. **Connect via SSH**

   **Important Network Requirements:**

   - **Direct Connection (UiS Campus Network Required):** If you are physically on campus , you can connect directly to your VM's floating IP
   - **Remote Connection (Use Jump VM):** If you are off-campus, you must use the provided jump VM to access your instance

   **Option A - Direct Connection (On UiS Campus Network):**

   ```console
   ssh ubuntu@floating_ip -i ssh_key
   ```

   **Option B - Remote Connection via Jump VM (Off-Campus):**

   First, connect to the jump VM:

   ```console
   ssh github_username@sshvm.cs.ux.uis.no
   ```

   Then from the jump VM, connect to your instance using private ip:

   ```console
   ssh ubuntu@private_ip -i ssh_key
   ```

   **Alternative - SSH Tunneling (Advanced):**

   You can also set up SSH tunneling through the jump host:

   ```console
   ssh -J github_username@sshvm.cs.ux.uis.no ubuntu@floating_ip -i ssh_key
   ```

   **Network Access Summary:**

   - **On UiS Campus:** Direct connection to floating IP works
   - **Off-Campus :** Must use jump VM or SSH tunneling

   **Note:** The floating IP is only accessible from UiS network ranges. External access requires going through the jump host.

## Task 2 - Install Docker

1. **Update and install**

   ```console
   sudo apt update && sudo apt upgrade
   sudo reboot # only needed if the kernel was updated; log back in via SSH afterwards
   sudo apt install docker.io
   ```

2. **Allow your user to run Docker without `sudo`**

   ```console
   sudo usermod -aG docker ${USER}
   ```

   Log out and back in, then confirm with `groups` that `docker` is listed.

3. **Configure the OpenStack MTU fix**

   OpenStack VMs use overlay networks with a reduced MTU. Configure Docker to match:

   ```console
   ip address # check your network interface's MTU
   echo '{"mtu": 1450}' | sudo tee /etc/docker/daemon.json > /dev/null
   sudo systemctl restart docker
   ip address show docker0 # should now show MTU 1450 too
   ```

4. **Verify the installation**

   ```console
   docker --version
   docker run hello-world
   docker system info
   ```

## Task 3 - Container Lifecycle and Ports

1. **Run, inspect, and log**

   ```console
   docker run -d -p 8080:80 --name web nginx:alpine
   docker ps
   curl localhost:8080
   docker logs web
   docker exec -it web sh -c 'ps aux; exit' # exec into the running container
   ```

2. **Stop, start, and remove**

   ```console
   docker stop web
   docker start web
   docker rm -f web
   ```

3. **Run a second instance and compare ports**

   ```console
   docker run -d -p 8080:80 --name web1 nginx:alpine
   docker run -d -p 8081:80 --name web2 nginx:alpine
   curl localhost:8080
   curl localhost:8081
   docker port web1
   docker port web2
   docker inspect web1 | grep IPAddress
   docker network ls
   docker rm -f web1
   docker rm -f web2
   ```

## Task 4 - Configuration, Persistence, and Debugging

1. **Watch a container fail, and find out why**

   ```console
   docker run -d --name db mysql:8.0
   docker ps -a # note the container has already exited
   docker logs db # explains that MYSQL_ROOT_PASSWORD (or one of its alternatives) is required
   docker rm db
   ```

2. **Re-run it correctly, with configuration and a named volume**

   ```console
   docker volume create db_data
   docker run -d --name db \
     -e MYSQL_ROOT_PASSWORD=mypassword \
     -e MYSQL_DATABASE=testdb \
     -v db_data:/var/lib/mysql \
     -p 3306:3306 \
     mysql:8.0
   docker logs -f db # wait for "ready for connections", then Ctrl-C
   ```

3. **Insert a row, then destroy and recreate the container**

   ```console
   docker exec -it db mysql -uroot -pmypassword testdb \
     -e "CREATE TABLE t (msg TEXT); INSERT INTO t VALUES ('still here?');"

   docker rm -f db # the container is gone, but the volume is not

   docker run -d --name db \
     -e MYSQL_ROOT_PASSWORD=mypassword \
     -v db_data:/var/lib/mysql \
     -p 3306:3306 \
     mysql:8.0

   docker exec -it db mysql -uroot -pmypassword testdb -e "SELECT * FROM t;"
   ```

   The row survives because the data lived in the volume, not the container.

4. **Resource usage and cleanup**

   ```console
   docker stats --no-stream
   docker system df
   docker stop db
   docker volume rm db_data # after removing the db container
   docker container prune # remove all stopped containers
   ```

## Next Steps

Proceed to [Part 2: Building and Shipping Images](../2-build/README.md).
