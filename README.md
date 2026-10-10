# ssh-tunnel

Shell scripts for reaching web interfaces that are only reachable from
inside a network (iDRAC, iLO, IPMI, switch UIs, admin panels) through an SSH
jump host. Each tunnel gets the next free local port, and you open
`https://localhost:<port>` in your browser.

```
browser ──https://localhost:8443──> ssh ──> jump host ──> target:443
```

## Scripts

| Script | What it does |
|---|---|
| `ssh-tunnel.sh` | Opens one tunnel. Small and dependency-free. |
| `ssh-tunnel-status.sh` | Lists the SSH tunnels on ports 8443-8500 and closes one or all. Only touches `ssh` processes. |
| `ssh-tunnel-manager.sh` | Everything in one tool: several tunnels at once, batch files, a config file, an interactive menu, state tracking and a dry run. Needs bash 4+. |

## Quick start

```bash
git clone https://github.com/j551n-ncloud/ssh-tunnel.git
cd ssh-tunnel

JUMP_HOST=jump.example.com SSH_USER=me ./ssh-tunnel.sh idrac01.example.com
# Tunnel established: https://localhost:8443 -> idrac01.example.com:443 via jump.example.com

./ssh-tunnel-status.sh          # list and close
```

`ssh-tunnel.sh` reads `JUMP_HOST`, `SSH_USER`, `BASE_PORT` (default 8443)
and `TARGET_PORT` (default 443) from the environment, and asks for the target
if you do not pass it.

## ssh-tunnel-manager.sh

```bash
./ssh-tunnel-manager.sh config                                 # save jump host, user, ports
./ssh-tunnel-manager.sh create idrac01.example.com idrac02.example.com
./ssh-tunnel-manager.sh list
./ssh-tunnel-manager.sh close 8443
./ssh-tunnel-manager.sh close-all
./ssh-tunnel-manager.sh interactive                            # menu
./ssh-tunnel-manager.sh --batch tunnels.txt                    # one target per line
./ssh-tunnel-manager.sh --help
```

Batch file format:

```
# comments start with #
idrac01.example.com
idrac02.example.com:8444           # custom target port
idrac03.example.com --port 9000    # custom local base port
```

It keeps its configuration in `~/.ssh-tunnel-config`, a log in
`~/.ssh-tunnel.log` and the open tunnels in `~/.ssh-tunnels-state`.

## Requirements

- SSH access to the jump host, ideally with a key (`ssh-copy-id`), and
  `AllowTcpForwarding` enabled there
- `lsof` for finding free ports and open tunnels
- bash 4+ for `ssh-tunnel-manager.sh`; macOS ships bash 3.2, so
  `brew install bash`

## Tips

- With `ProxyJump` in `~/.ssh/config` you can reach the targets' SSH as well:
  `Host idrac-* \n ProxyJump jump.example.com`.
- The browser will warn about the target's certificate, because it was
  issued for the target's name, not `localhost`.

## License

MIT
