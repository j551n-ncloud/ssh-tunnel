


# SSH Tunnel Setup for iDRAC Access

This script establishes an SSH tunnel from your local machine to an iDRAC interface via a jump host. Once the tunnel is set up, you can access the iDRAC web interface locally through your browser.

## Prerequisites

- **SSH Access**: You must have SSH access to the jump host (`odcf-admin01.dkfz-heidelberg.de`) and the appropriate credentials (username and password or SSH key).
- **iDRAC FQDN**: You need the Fully Qualified Domain Name (FQDN) of the iDRAC server to establish the tunnel.

## Setup Instructions

1. **Clone or Download the Script**

   Download the `idrac_tunnel.sh` script to your local machine. You can copy the content from the script above or download it from your source.

2. **Make the Script Executable**

   After downloading or saving the script, navigate to the directory where the script is located and run the following command to make it executable:
   
   ```bash
   chmod +x idrac_tunnel.sh
   ```

3. **Run the Script**

   Run the script with the following command:
   
   ```bash
   ./idrac_tunnel.sh
   ```

4. **Enter iDRAC FQDN**

   When prompted, **enter the FQDN** (e.g., `idrac.example.com`) of the iDRAC server. This will establish the SSH tunnel to the specified iDRAC interface through the jump host.

   ```
   Enter the FQDN of the iDRAC server: idrac.example.com
   ```

5. **Access iDRAC**

   After the tunnel is established, you can access the iDRAC web interface by navigating to the following URL in your web browser:
   
   ```
   https://localhost:8443
   ```

   The local port `8443` will forward your browser traffic to the remote iDRAC server over port `443`.

## Example Usage

```bash
Enter the FQDN of the iDRAC server: idrac.example.com
Setting up SSH tunnel to iDRAC (idrac.example.com) via jump host...
Tunnel established! Access iDRAC at https://localhost:8443
```

## Notes

- **Local Port**: The script uses **local port `8443`** for the tunnel. If this port is already in use, you can modify the `LOCAL_PORT` variable in the script.
  
- **Jump Host**: The script connects via the jump host `odcf-admin01.dkfz-heidelberg.de`. Modify the `JUMP_HOST` variable if the jump host address is different.

- **Access iDRAC via Browser**: After the tunnel is established, use `localhost:8443` to connect to the iDRAC interface.

## Troubleshooting

- **SSH Connection Issues**: Ensure that your SSH credentials and network access to the jump host are correct.
  
- **Port Conflicts**: If `8443` is already in use, you can change it by updating the `LOCAL_PORT` in the script.
  
- **Firewall/Network Configuration**: Ensure that the iDRAC FQDN is accessible from the jump host and that no firewalls are blocking port `443` on the iDRAC.

## Conclusion

This SSH tunneling script provides an easy and secure way to access the iDRAC web interface from your local machine via a jump host. It simplifies the process of managing remote iDRAC servers behind firewalls or private networks.