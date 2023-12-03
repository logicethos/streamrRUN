#!/bin/sh
# Streamr Node iptables firewall script
# Rate limits repeated connections.
# Traffic to be rate limted, are sent to the RATE-LIMIT table
#

ClearTable()
{
        echo "Clearing INPUT chain"
        iptables --flush INPUT
        iptables --policy INPUT ACCEPT
        iptables --delete-chain RATE-LIMIT 2> /dev/null || true
}

SetupPre()
{
        iptables --flush INPUT                                                  # Clear INPUT Table
        iptables --policy INPUT DROP                                            # Default to drop packets
        iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT  # pass through existing connections
        iptables -A INPUT -i lo -p all -j ACCEPT                                # pass through local traffic
        iptables -A INPUT -p tcp -m tcp --tcp-flags ACK ACK -j ACCEPT           # pass through ACKs
               
}

SetupPost()
{
        # --- RATE-LIMIT chain ---
        (iptables --flush RATE-LIMIT || iptables --new-chain RATE-LIMIT) 2> /dev/null  # Create/clear RATE-LIMIT table

        #Track source IP, and if within limits accept
        iptables --append RATE-LIMIT --match hashlimit --hashlimit-mode srcip --hashlimit-upto 3/sec  --hashlimit-burst 20  --hashlimit-name conn_rate_limit  --jump ACCEPT

        #Log limit hits
        iptables --append RATE-LIMIT --jump LOG --log-prefix "Rate Limit: "
        iptables --append RATE-LIMIT -j DROP
}

PrivilegedAccess()
{
    #  iptables -A INPUT -p tcp -s 123.123.123.123 -j ACCEPT   # Your office IP, or other trusted IP address
}

RegularPorts()
{
        iptables -A INPUT -p icmp -m limit --limit 10/second -j RATE-LIMIT          #ICMP packets
        iptables -A INPUT -p tcp --dport 22 -j RATE-LIMIT                           #ssh
}

App()
{
        iptables -A INPUT -p tcp --dport 32200 -j RATE-LIMIT                           #Streamr
}

case "$1" in
  start)
        SetupPre
        PrivilegedAccess
        SetupPost
        RegularPorts
        App
    ;;
  stop|clear)
        ClearTable                                        
    ;;
  *)
    echo "Usage: iptables.sh {start|stop} $1"
    exit 1
    ;;
esac
exit 0            
