# SSH Tunnel Management for iDRAC Access

This repository contains two shell scripts designed to help you create and manage SSH tunnels for accessing an iDRAC server through a jump host. The scripts are intended to establish secure SSH tunnels, provide access to the iDRAC web interface, and allow you to manage active tunnels on your local machine.

## Prerequisites

Before using these scripts, ensure you have the following:

- **SSH access to the jump host** (via a valid SSH key or password).
- **iDRAC credentials** (Fully Qualified Domain Name (FQDN) and access credentials for the iDRAC server).
- **The `lsof` command** installed on your system (used for checking active ports).

## Script Overview

### 1. **Create SSH Tunnel for iDRAC Access**

This script allows you to create an SSH tunnel through a jump host to access an iDRAC server. It forwards traffic from a local port on your machine to the iDRAC port, providing a secure connection to the iDRAC interface.

**Functionality:**
- Prompts you to enter the Fully Qualified Domain Name (FQDN) of the iDRAC server.
- Automatically detects the next available local port on your machine to establish the tunnel.
- Provides a URL (`https://localhost:<local_port>`) to access the iDRAC interface securely through the tunnel.

### 2. **List and Close Active SSH Tunnels**

This script lists all active SSH tunnels on your local machine, allowing you to identify and close any open tunnels. It is useful for managing and maintaining SSH connections, especially when there are multiple tunnels in use.

**Functionality:**
- Scans for active SSH tunnels starting from a specified base port.
- Lists all active tunnels and their corresponding ports.
- Prompts you to select a specific tunnel to close or allows you to close all active tunnels at once.

## How to Use

### Step 1: Create the SSH Tunnel

To create an SSH tunnel to access the iDRAC server, follow these steps:

1. Run the script designed for tunnel creation.
2. Enter the **FQDN of the iDRAC server** when prompted.
3. The script will automatically find an available local port and establish the tunnel.
4. After successful creation, you can access the iDRAC interface by navigating to `https://localhost:<local_port>`.

### Step 2: List and Close Active SSH Tunnels

To manage active SSH tunnels on your local machine, follow these steps:

1. Run the script that lists and closes SSH tunnels.
2. The script will search for active tunnels and display a list of ports in use.
3. Choose to close a specific tunnel by entering the associated port number or type `all` to close all active tunnels.

## Notes

- The SSH tunnel forwards traffic from a local port (on your laptop) to the iDRAC server's HTTPS port (443).
- Ensure that SSH tunneling is enabled on the jump host and that your firewall/security settings allow such connections.
- The second script is useful for managing multiple active tunnels on your local machine.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.