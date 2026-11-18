# Updates trafx-socks to the latest image; settings (envs) are kept.
#   /tool fetch url="https://raw.githubusercontent.com/alirezamshk/trafx-socks-install/main/update.rsc" dst-path=trafx-socks-update.rsc
#   /import trafx-socks-update.rsc
{
:local image "ghcr.io/alirezamshk/trafx-socks:latest"
:local ctName "trafx-socks"
:local mark "trafx-socks"

:if ([:len [/container find where name=$ctName]] = 0) do={ :error "trafx-socks is not installed" }
:local iface [/container get [find where name=$ctName] interface]
:local root [/container get [find where name=$ctName] root-dir]
# Installed with ocserv: keep that image and the /data mount.
:local oc ([:len [/container envs find where list="ENV_TRAFX_SOCKS" and key="OCSERV_ENABLED" and value="1"]] > 0)
:if ($oc) do={ :set image "ghcr.io/alirezamshk/trafx-socks:ocserv" }
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
:if ($oc) do={
  /container add remote-image=$image interface=$iface envlists="ENV_TRAFX_SOCKS" mountlists="MOUNT_TRAFX_SOCKS" root-dir=$root name=$ctName start-on-boot=yes restart-policy=on-failure stop-time=30s logging=yes
} else={
  /container add remote-image=$image interface=$iface envlists="ENV_TRAFX_SOCKS" root-dir=$root name=$ctName start-on-boot=yes restart-policy=on-failure stop-time=30s logging=yes
}

:local id [/container find where name=$ctName]
# Keep asking for a start until it runs: a start sent while the image is
# still downloading is accepted but does nothing.
:local running false
:for i from=1 to=100 do={
  :if (!$running) do={
    :do { /container start $id } on-error={}
    :delay 3s
    :if ([/container get $id running]) do={ :set running true }
  }
}
:if ($running) do={
  :put "trafx-socks: updated and running"
} else={
  :put "trafx-socks: did not stay running; see /log print where message~\"trafx\""
}
}
