{ ... }:

# Expose the nemousu.live-on.net redirector on the well-known ports.
# The pod runs as a NodePort Service (30080/30443) in bbs/, because
# Kubernetes' default --service-node-port-range is 30000-32767 and
# widening it cluster-wide for one Service isn't worth the blast
# radius. Caddy still needs :80 for the Let's Encrypt HTTP-01
# challenge, so we REDIRECT (localhost-DNAT) :80/:443 to the
# NodePorts in nat PREROUTING; kube-proxy's KUBE-SERVICES jump runs
# after ours (kube-proxy appends, we insert at position 1) and DNATs
# further to the pod IP, so the packet leaves via FORWARD — no
# `allowedTCPPorts` entry needed for :80/:443 or the NodePorts.
{
  networking.firewall.extraCommands = ''
    iptables -w -t nat -N nemousu-redirect 2>/dev/null || iptables -w -t nat -F nemousu-redirect
    iptables -w -t nat -A nemousu-redirect -p tcp --dport 80  -j REDIRECT --to-ports 30080
    iptables -w -t nat -A nemousu-redirect -p tcp --dport 443 -j REDIRECT --to-ports 30443
    iptables -w -t nat -C PREROUTING -i ens3 -p tcp -m multiport --dports 80,443 -j nemousu-redirect 2>/dev/null || \
      iptables -w -t nat -I PREROUTING 1 -i ens3 -p tcp -m multiport --dports 80,443 -j nemousu-redirect
  '';

  networking.firewall.extraStopCommands = ''
    iptables -w -t nat -D PREROUTING -i ens3 -p tcp -m multiport --dports 80,443 -j nemousu-redirect 2>/dev/null || true
    iptables -w -t nat -F nemousu-redirect 2>/dev/null || true
    iptables -w -t nat -X nemousu-redirect 2>/dev/null || true
  '';
}
