# Removes everything trafx-socks-install.rsc created (comment "trafx-socks").
#   /tool fetch url="https://raw.githubusercontent.com/alirezamshk/trafx-socks-install/main/uninstall.rsc" dst-path=trafx-socks-uninstall.rsc
#   /import trafx-socks-uninstall.rsc
{
:local ctName "trafx-socks"
:local mark "trafx-socks"

# Stop and remove an existing container, waiting for each step: removal is
# asynchronous and its veth stays "in use" until it has finished.
:if ([:len [/container find where name=$ctName]] > 0) do={
  :local old [:pick [/container find where name=$ctName] 0]
  :do { /container set $old restart-policy=no } on-error={}
  :do { /container stop $old } on-error={}
  :local n 0
  :while ([/container get $old running] and $n < 60) do={ :delay 1s; :set n ($n + 1) }
  # "Stopping" still counts as running: retry until the removal is accepted.
  :local removed false
  :for i from=1 to=90 do={
    :if (!$removed) do={
      :do { /container remove $old; :set removed true } on-error={ :delay 1s }
    }
  }
  :if (!$removed) do={ :error "old container did not stop; try again in a minute" }
  :set n 0
  :while ([:len [/container find where name=$ctName]] > 0 and $n < 40) do={ :delay 1s; :set n ($n + 1) }
  :delay 2s
}
/container envs remove [find where list="ENV_TRAFX_SOCKS"]
/ip firewall mangle remove [find where comment~"^trafx-socks"]
/ip firewall nat remove [find where comment~"^trafx-socks"]
/ip route remove [find where comment~"^trafx-socks"]
/routing table remove [find where comment~"^trafx-socks"]
# The mount entry goes; its folder (certificate, acme.sh account) stays on
# disk so a reinstall does not ask Let's Encrypt again. Delete it by hand.
/container mounts remove [find where list="MOUNT_TRAFX_SOCKS"]
/interface bridge port remove [find where comment=$mark]
/interface veth remove [find where comment=$mark]
/ip address remove [find where comment=$mark]
/interface bridge remove [find where comment=$mark]
:put "trafx-socks: removed"
}
