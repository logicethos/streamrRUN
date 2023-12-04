#!/bin/bash
# Streamr Node iptables firewall script
# Rate limits repeated connections.
# Traffic to be rate limted, are sent to the RATE-LIMIT table
#


if [ -z "$MAXCON" ]; then   #Maximum connections from a single source IP
    MAXCON=10
fi


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
        # --- Create RATE-LIMIT chain ---
        (iptables --flush RATE-LIMIT || iptables --new-chain RATE-LIMIT) 2> /dev/null

        #Maximum connections per source IP.
        iptables --append RATE-LIMIT -p tcp --syn --match connlimit --connlimit-above $MAXCON --jump LOG --log-prefix "Max Connections: "

        #Track source IP, and if within limits accept
        iptables --append RATE-LIMIT --match hashlimit --hashlimit-mode srcip --hashlimit-upto 3/sec  --hashlimit-burst 20  --hashlimit-name conn_rate_limit  --jump ACCEPT

        #Log limit hits
        iptables --append RATE-LIMIT --jump LOG --log-prefix "Rate Limit: "
        iptables --append RATE-LIMIT -j DROP
}

PrivilegedAccess()
{
      if [ ${#TrustedIP[@]} -gt 0 ]; then
         for ip_or_domain in "${TrustedIP[@]}"; do
            # Apply iptables rule for each trusted IP or domain
            iptables -A INPUT -p tcp -s "$ip_or_domain" -j ACCEPT
         done
      fi
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
