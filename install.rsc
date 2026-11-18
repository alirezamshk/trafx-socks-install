# trafx-socks installer for MikroTik RouterOS 7 (container package).
#
# Set these, then fetch and import this file:
#
#   :global tsPanel "PANEL_IP"
#   :global tsSecret "NAS_SECRET"
#   :global tsLicense "TXS1...."
#   :global tsTunnel "to-uk"            (optional: routing table users leave through)
#   :global tsPublicIP "x.x.x.x"        (optional: detected from the default route)
#   :global tsDisk "disk1"              (optional: detected)
#   :global tsPort "1080"               (optional)
#   :global tsHttp "yes"                (optional: HTTP proxy on the same port, same accounts)
#   :global tsHttps "yes"               (optional: HTTPS proxy (TLS) on the same port; uses the
#                                       Let's Encrypt certificate, so needs tsOcserv + tsOcHost + tsOcEmail;
#                                       clients connect to the host name, not the IP)
#
# ocserv (OpenConnect / AnyConnect) in the same container, same panel NAS,
# same license (optional):
#   :global tsOcserv "yes"
#   :global tsOcHost "oc.example.com"   (DNS A record -> this router; Cloudflare proxy off)
#   :global tsOcEmail "you@example.com" (Let's Encrypt; with tsOcHost, needs TCP 80 free)
#   :global tsOcPort "443"              (optional, default 443)
#   :global tsOcPool "10.20.0.0/16"     (optional, user addresses)
#   :global tsOcLocations "to-uk=UK;to-de=Germany"  (optional: exit=name per location; the exit is a
#                                       routing table, or a point-to-point tunnel interface (WireGuard,
#                                       GRE, IPIP, ...) for which a table is made; any name;
#                                       users pick one in AnyConnect, same host name and port)
#   :global tsOcDefaultName "Iran"      (optional: name of the entry without a location;
#                                       "none" = no such entry, the FIRST location is the default)
#   :global tsOcProfile "no"            (optional: locations only in the Group menu, not added
#                                       to the app's connection list; default "yes")
#   :global tsImageFile "disk1/trafx-socks-ocserv-amd64.tar"  (optional: image tar on the router instead of the registry)
#   /tool fetch url="https://raw.githubusercontent.com/alirezamshk/trafx-socks-install/main/install.rsc" dst-path=trafx-socks-install.rsc
#   /import trafx-socks-install.rsc
#
# Re-running is safe: it replaces its own pieces. Everything it creates
# carries the comment "trafx-socks"; uninstall.rsc removes exactly those.
{
:global tsPanel
:global tsSecret
:global tsLicense
:global tsTunnel
:global tsPublicIP
:global tsDisk
:global tsPort
:global tsHttp
:global tsHttps
:global tsOcserv
:global tsOcHost
:global tsOcEmail
:global tsOcPort
:global tsOcPool
:global tsOcLocations
:global tsOcDefaultName
:global tsOcProfile
:global tsImageFile

:local ctName "trafx-socks"
# Variable names must not match a property of the items being searched
# (e.g. containers have "tag" and "name"): inside "find where" RouterOS
# reads the item's property instead of the variable.
:local mark "trafx-socks"
:local envList "ENV_TRAFX_SOCKS"
:local vethName "veth-trafx-socks"
:local bridge "br-trafx-socks"
:local gateway "172.31.250.1"
:local net "172.31.250.0/24"
:local inIP "172.31.250.2"
:local outIP "172.31.250.3"
:local image "ghcr.io/alirezamshk/trafx-socks:latest"
:local ocImage "ghcr.io/alirezamshk/trafx-socks:ocserv"
:local mountList "MOUNT_TRAFX_SOCKS"
:local ocMark "trafx-socks ocserv"

# Re-install: panel, secret and license not given are taken from the
# existing settings, so they need not be typed again.
:if (([:typeof $tsPanel] != "str" or [:len $tsPanel] = 0) and [:len [/container envs find where list=$envList and key="RADIUS_SERVER"]] > 0) do={
  :set tsPanel [/container envs get [:pick [/container envs find where list=$envList and key="RADIUS_SERVER"] 0] value]
}
:if (([:typeof $tsSecret] != "str" or [:len $tsSecret] = 0) and [:len [/container envs find where list=$envList and key="RADIUS_SECRET"]] > 0) do={
  :set tsSecret [/container envs get [:pick [/container envs find where list=$envList and key="RADIUS_SECRET"] 0] value]
}
:if (([:typeof $tsLicense] != "str" or [:len $tsLicense] = 0) and [:len [/container envs find where list=$envList and key="LICENSE"]] > 0) do={
  :set tsLicense [/container envs get [:pick [/container envs find where list=$envList and key="LICENSE"] 0] value]
}
:if ([:typeof $tsTunnel] != "str") do={
  :local prev [/ip firewall mangle find where comment=$mark and action="mark-routing"]
  :if ([:len $prev] > 0) do={ :set tsTunnel [/ip firewall mangle get [:pick $prev 0] new-routing-mark] }
}
:if ([:typeof $tsOcserv] != "str" and [:len [/container envs find where list=$envList and key="OCSERV_ENABLED" and value="1"]] > 0) do={
  :set tsOcserv "yes"
}
:if ([:typeof $tsHttp] != "str" and [:len [/container envs find where list=$envList and key="HTTP_ENABLED" and value="1"]] > 0) do={
  :set tsHttp "yes"
}
:if ([:typeof $tsHttps] != "str" and [:len [/container envs find where list=$envList and key="HTTPS_ENABLED" and value="1"]] > 0) do={
  :set tsHttps "yes"
}
:if (([:typeof $tsOcHost] != "str" or [:len $tsOcHost] = 0) and [:len [/container envs find where list=$envList and key="OCSERV_HOST"]] > 0) do={
  :set tsOcHost [/container envs get [:pick [/container envs find where list=$envList and key="OCSERV_HOST"] 0] value]
}
:if (([:typeof $tsOcEmail] != "str" or [:len $tsOcEmail] = 0) and [:len [/container envs find where list=$envList and key="ACME_EMAIL"]] > 0) do={
  :set tsOcEmail [/container envs get [:pick [/container envs find where list=$envList and key="ACME_EMAIL"] 0] value]
}
:if ([:typeof $tsOcLocations] != "str" and [:len [/container envs find where list=$envList and key="TRAFX_OC_LOCATIONS"]] > 0) do={
  :set tsOcLocations [/container envs get [:pick [/container envs find where list=$envList and key="TRAFX_OC_LOCATIONS"] 0] value]
}
:if ([:typeof $tsOcProfile] != "str" and [:len [/container envs find where list=$envList and key="OCSERV_PROFILE" and value="0"]] > 0) do={
  :set tsOcProfile "no"
}
:if ([:typeof $tsOcDefaultName] != "str" and [:len [/container envs find where list=$envList and key="OCSERV_DEFAULT_NAME"]] > 0) do={
  :set tsOcDefaultName [/container envs get [:pick [/container envs find where list=$envList and key="OCSERV_DEFAULT_NAME"] 0] value]
}

# ---- checks (nothing is changed before these pass) ----
:if ([:typeof $tsPanel] != "str" or [:len $tsPanel] = 0) do={ :error "set :global tsPanel \"PANEL_IP\"" }
:if ([:typeof $tsSecret] != "str" or [:len $tsSecret] < 8) do={ :error "set :global tsSecret (8+ characters, same as the NAS in the panel)" }
:if ([:typeof $tsLicense] != "str" or [:pick $tsLicense 0 5] != "TXS1.") do={ :error "set :global tsLicense \"TXS1....\"" }
:local tunnel ""
:if ([:typeof $tsTunnel] = "str") do={ :set tunnel $tsTunnel }
:if ([:len $tunnel] > 0 and [:len [/routing table find where name=$tunnel]] = 0) do={ :error ("routing table " . $tunnel . " not found") }
:local port "1080"
:if ([:typeof $tsPort] = "str" and [:len $tsPort] > 0) do={ :set port $tsPort }
:if ([:len [/system package find where name="container" and !disabled]] = 0) do={ :error "install and enable the container package first" }
:local arch [/system resource get architecture-name]
# x86_64 -> amd64 image, arm64 -> arm64, arm (32-bit ARMv7) -> arm/v7.
# The container package needs enough RAM and storage (the ocserv image is
# about 100 MB); MIPS / PowerPC / TILE routers cannot run containers.
:if ($arch != "x86_64" and $arch != "arm64" and $arch != "arm") do={ :error ("unsupported architecture " . $arch . " (x86_64, arm64, arm)") }

# ocserv options.
:local oc false
:if ([:typeof $tsOcserv] = "str" and ($tsOcserv = "yes" or $tsOcserv = "1" or $tsOcserv = "true")) do={ :set oc true }
:local ocPort "443"
:if ([:typeof $tsOcPort] = "str" and [:len $tsOcPort] > 0) do={ :set ocPort $tsOcPort }
:local ocPool "10.20.0.0/16"
:if ([:typeof $tsOcPool] = "str" and [:len $tsOcPool] > 0) do={ :set ocPool $tsOcPool }
:local ocHost ""
:if ([:typeof $tsOcHost] = "str") do={ :set ocHost $tsOcHost }
:local ocEmail ""
:if ([:typeof $tsOcEmail] = "str") do={ :set ocEmail $tsOcEmail }
:local acme ($oc and [:len $ocHost] > 0 and [:len $ocEmail] > 0)
:local http false
:if ([:typeof $tsHttp] = "str" and ($tsHttp = "yes" or $tsHttp = "1" or $tsHttp = "true")) do={ :set http true }
:local https false
:if ([:typeof $tsHttps] = "str" and ($tsHttps = "yes" or $tsHttps = "1" or $tsHttps = "true")) do={ :set https true }
:if ($https and !$acme) do={ :error "tsHttps needs the Let's Encrypt certificate: set tsOcserv \"yes\", tsOcHost and tsOcEmail" }

# Locations: "exit=Name;exit=Name". The exit is a routing table, or a
# point-to-point tunnel interface (then a table "trafx-oc-<id>" with a default
# route over it is made). Each location gets pool 10.(21+n).0.0/16; its group
# id is the exit name in lower case, other characters as "-", without a
# leading "to-".
:local locSpec ""
:if ([:typeof $tsOcLocations] = "str") do={ :set locSpec $tsOcLocations }
:local defName "Default"
:if ([:typeof $tsOcDefaultName] = "str" and [:len $tsOcDefaultName] > 0) do={ :set defName $tsOcDefaultName }
:local locTables [:toarray ""]
:local locIfaces [:toarray ""]
:local locPools [:toarray ""]
:local locGids ";"
:local upper "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
:local lower "abcdefghijklmnopqrstuvwxyz"
:local idChars "abcdefghijklmnopqrstuvwxyz0123456789_-"
:local locEnv ""
:local rest $locSpec
:local n 0
:while ([:len $rest] > 0) do={
  :local item $rest
  :local sep [:find $rest ";"]
  :if ([:typeof $sep] = "nil") do={
    :set rest ""
  } else={
    :set item [:pick $rest 0 $sep]
    :set rest [:pick $rest ($sep + 1) [:len $rest]]
  }
  :if ([:len $item] > 0) do={
    :local eq [:find $item "="]
    :if ([:typeof $eq] = "nil") do={ :error ("tsOcLocations: use exit=Name, got " . $item) }
    :local tbl [:pick $item 0 $eq]
    :local lname [:pick $item ($eq + 1) [:len $item]]
    :if ([:len $tbl] = 0) do={ :error ("tsOcLocations: no exit in " . $item) }
    :if ([:len $lname] = 0 or [:typeof [:find $lname ":"]] != "nil") do={ :error ("tsOcLocations: bad name for " . $tbl) }
    # Group id: lower case, other characters "-", no leading "to-".
    :local gid ""
    :for i from=0 to=([:len $tbl] - 1) do={
      :local ch [:pick $tbl $i]
      :local up [:find $upper $ch]
      :if ([:typeof $up] != "nil") do={ :set ch [:pick $lower $up] }
      :if ([:typeof [:find $idChars $ch]] = "nil") do={ :set ch "-" }
      :set gid ($gid . $ch)
    }
    :if ([:pick $gid 0 3] = "to-") do={ :set gid [:pick $gid 3 [:len $gid]] }
    :if ([:len $gid] = 0 or $gid = "main") do={ :error ("tsOcLocations: " . $tbl . " gives group id \"" . $gid . "\"; rename it") }
    :if ([:typeof [:find $locGids (";" . $gid . ";")]] != "nil") do={ :error ("tsOcLocations: two exits give the same group id " . $gid) }
    :set locGids ($locGids . $gid . ";")
    # The exit: a routing table, else a tunnel interface (a table is made).
    :local markTbl $tbl
    :local viaIf "-"
    :if ([:len [/routing table find where name=$tbl]] = 0) do={
      :if ([:len [/interface find where name=$tbl]] = 0) do={ :error ("tsOcLocations: " . $tbl . " is neither a routing table nor an interface") }
      :set viaIf $tbl
      :set markTbl ("trafx-oc-" . $gid)
    }
    :set n ($n + 1)
    :if ($n > 10) do={ :error "tsOcLocations: at most 10 locations" }
    :local lpool ("10." . (20 + $n) . ".0.0/16")
    :set locTables ($locTables, $markTbl)
    :set locIfaces ($locIfaces, $viaIf)
    :set locPools ($locPools, $lpool)
    :if ([:len $locEnv] > 0) do={ :set locEnv ($locEnv . ";") }
    :set locEnv ($locEnv . $gid . ":" . $lname . ":" . $lpool)
  }
}
:if ($n > 0 and !$oc) do={ :error "tsOcLocations needs :global tsOcserv \"yes\"" }
:if ($oc and [:len $ocHost] > 0 and [:len $ocEmail] = 0) do={ :error "tsOcHost needs tsOcEmail for the Let's Encrypt certificate" }

# Public IP: given, or the address on the interface of the main default route.
:local publicIP ""
:if ([:typeof $tsPublicIP] = "str" and [:len $tsPublicIP] > 0) do={
  :set publicIP $tsPublicIP
} else={
  :local r [/ip route find where dst-address="0.0.0.0/0" and routing-table="main" and active]
  :if ([:len $r] = 0) do={ :error "no active default route; set :global tsPublicIP" }
  :local gw [:tostr [/ip route get [:pick $r 0] immediate-gw]]
  :local pct [:find $gw "%"]
  :if ([:typeof $pct] = "nil") do={ :error "cannot find the WAN interface; set :global tsPublicIP" }
  :local wan [:pick $gw ($pct + 1) [:len $gw]]
  :local a [/ip address find where interface=$wan and !disabled]
  :if ([:len $a] = 0) do={ :error ("no address on " . $wan . "; set :global tsPublicIP") }
  :local addr [/ip address get [:pick $a 0] address]
  :set publicIP [:pick $addr 0 [:find $addr "/"]]
}

# Disk: given, or disk1 when present, else internal storage.
:local disk ""
:if ([:typeof $tsDisk] = "str" and [:len $tsDisk] > 0) do={
  :set disk ($tsDisk . "/")
} else={
  :if ([:len [/file find where name="disk1"]] > 0) do={ :set disk "disk1/" }
}
:put ("trafx-socks: public IP " . $publicIP . ", panel " . $tsPanel . ", tunnel " . $tunnel . ", disk " . $disk)

# ocserv ports must be free on the router: stop here, before any change,
# rather than take a port from a service the operator may be using.
:if ($oc) do={
  :foreach s in=[/ip service find where !disabled and !dynamic and port=[:tonum $ocPort]] do={
    :error ("router service " . [/ip service get $s name] . " uses port " . $ocPort . "; move it first, e.g. /ip service set " . [/ip service get $s name] . " port=8443")
  }
  :if ([/interface sstp-server server get enabled] and [/interface sstp-server server get port] = [:tonum $ocPort]) do={
    :error ("SSTP server uses port " . $ocPort . "; move it or set :global tsOcPort")
  }
  :if ([:len [/ip firewall nat find where chain=dstnat and dst-port=$ocPort and !(comment~"^trafx-socks")]] > 0) do={
    :error ("port " . $ocPort . " is already forwarded by another NAT rule")
  }
  :if ($acme) do={
    :foreach s in=[/ip service find where !disabled and !dynamic and port=80] do={
      :error ("router service " . [/ip service get $s name] . " uses port 80, which Let's Encrypt needs; move it first, e.g. /ip service set " . [/ip service get $s name] . " port=8080")
    }
    :if ([:len [/ip firewall nat find where chain=dstnat and dst-port="80" and !(comment~"^trafx-socks")]] > 0) do={
      :error "port 80 is already forwarded by another NAT rule; Let's Encrypt needs it (or share it with Caddy)"
    }
  }
  :put ("trafx-socks: ocserv on port " . $ocPort . ", pool " . $ocPool)
  :if ($n > 0) do={ :put ("trafx-socks: locations " . $defName . ";" . $locEnv) }
  :if ($acme) do={
    :put ("trafx-socks: Let's Encrypt certificate for " . $ocHost)
  } else={
    :put "trafx-socks: self-signed certificate (set tsOcHost + tsOcEmail for Let's Encrypt)"
  }
}

# ---- network ----
:if ([:len [/interface bridge find where name=$bridge]] = 0) do={
  /interface bridge add name=$bridge comment=$mark
}
:if ([:len [/ip address find where interface=$bridge]] = 0) do={
  /ip address add address=($gateway . "/24") interface=$bridge comment=$mark
}
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
/interface bridge port remove [find where comment=$mark]
/interface veth remove [find where name=$vethName]
/interface veth add name=$vethName address=($inIP . "/24," . $outIP . "/24") gateway=$gateway comment=$mark
/interface bridge port add bridge=$bridge interface=$vethName comment=$mark

/ip firewall nat remove [find where comment~"^trafx-socks"]
/ip firewall mangle remove [find where comment~"^trafx-socks"]
/ip route remove [find where comment~"^trafx-socks"]
# Tables made for tunnel-interface exits (after their routes and marks are gone).
/routing table remove [find where comment=$ocMark]
# The real client address must reach the program: this accept goes first.
/ip firewall nat add chain=srcnat action=accept dst-address=$inIP comment=($mark . " keep client ip")
:local keep [/ip firewall nat find where comment=($mark . " keep client ip")]
:local first [:pick [/ip firewall nat find] 0]
:if ($first != $keep) do={ /ip firewall nat move $keep destination=$first }
/ip firewall nat add chain=srcnat action=masquerade src-address=$net comment=$mark
/ip firewall nat add chain=dstnat action=dst-nat protocol=tcp dst-address=$publicIP dst-port=$port to-addresses=$inIP to-ports=1080 comment=$mark
/ip firewall nat add chain=dstnat action=dst-nat protocol=udp dst-address=$publicIP dst-port=$port to-addresses=$inIP to-ports=1080 comment=$mark
/ip firewall nat add chain=dstnat action=dst-nat protocol=udp src-address=$tsPanel dst-address=$publicIP dst-port=3799 to-addresses=$inIP to-ports=3799 comment=$mark
:if ([:len $tunnel] > 0) do={
  /ip firewall mangle add chain=prerouting action=mark-routing new-routing-mark=$tunnel passthrough=no src-address=$outIP dst-address-type=!local comment=$mark
}
# Tunnels (GRE, WARP, ...) have a smaller MTU: clamp TCP MSS for traffic
# leaving the container, or large packets stall and downloads crawl.
/ip firewall mangle add chain=forward action=change-mss new-mss=1280 passthrough=yes protocol=tcp tcp-flags=syn tcp-mss=1281-65535 src-address=$net comment=$mark

# ocserv: users get addresses from the pool inside the container; the router
# routes the pool to it, NATs it out (through the tunnel, like SOCKS users,
# when there is one) and forwards the ports.
:if ($oc) do={
  /ip route add dst-address=$ocPool gateway=$inIP comment=$ocMark
  /ip firewall nat add chain=dstnat action=dst-nat protocol=tcp dst-address=$publicIP dst-port=$ocPort to-addresses=$inIP to-ports=$ocPort comment=$ocMark
  /ip firewall nat add chain=dstnat action=dst-nat protocol=udp dst-address=$publicIP dst-port=$ocPort to-addresses=$inIP to-ports=$ocPort comment=$ocMark
  :if ($acme) do={
    /ip firewall nat add chain=dstnat action=dst-nat protocol=tcp dst-address=$publicIP dst-port=80 to-addresses=$inIP to-ports=80 comment=$ocMark
  }
  /ip firewall nat add chain=srcnat action=masquerade src-address=$ocPool comment=$ocMark
  :if ([:len $tunnel] > 0) do={
    /ip firewall mangle add chain=prerouting action=mark-routing new-routing-mark=$tunnel passthrough=no src-address=$ocPool dst-address-type=!local comment=$ocMark
  }
  /ip firewall mangle add chain=forward action=change-mss new-mss=1280 passthrough=yes protocol=tcp tcp-flags=syn tcp-mss=1281-65535 src-address=$ocPool comment=$ocMark
  # One pool per location, out through its own routing table. (Guarded:
  # ":for k from=0 to=-1" would count down and run twice.)
  :if ([:len $locPools] > 0) do={ :for k from=0 to=([:len $locPools] - 1) do={
    :local lp ($locPools->$k)
    :local lt ($locTables->$k)
    :local li ($locIfaces->$k)
    :if ($li != "-") do={
      /routing table add name=$lt fib comment=$ocMark
      /ip route add dst-address=0.0.0.0/0 gateway=$li routing-table=$lt comment=$ocMark
    }
    /ip route add dst-address=$lp gateway=$inIP comment=$ocMark
    /ip firewall nat add chain=srcnat action=masquerade src-address=$lp comment=$ocMark
    /ip firewall mangle add chain=prerouting action=mark-routing new-routing-mark=$lt passthrough=no src-address=$lp dst-address-type=!local comment=$ocMark
    /ip firewall mangle add chain=forward action=change-mss new-mss=1280 passthrough=yes protocol=tcp tcp-flags=syn tcp-mss=1281-65535 src-address=$lp comment=$ocMark
  } }
}

# ---- settings for the program ----
/container envs remove [find where list=$envList]
/container envs add list=$envList key=RADIUS_SERVER value=$tsPanel
/container envs add list=$envList key=RADIUS_SECRET value=$tsSecret
/container envs add list=$envList key=NAS_IP value=$publicIP
/container envs add list=$envList key=LICENSE value=$tsLicense
/container envs add list=$envList key=LISTEN value=($inIP . ":1080")
/container envs add list=$envList key=COA_LISTEN value=($inIP . ":3799")
/container envs add list=$envList key=RADIUS_SOURCE_IP value=$inIP
/container envs add list=$envList key=BIND_IP value=$outIP
/container envs add list=$envList key=UDP_ADVERTISE_IP value=$publicIP
:if ([:len $tunnel] > 0) do={
  /container envs add list=$envList key=DNS value="1.1.1.1:53,8.8.8.8:53"
}
:if ($http) do={ /container envs add list=$envList key=HTTP_ENABLED value="1" }
:if ($https) do={ /container envs add list=$envList key=HTTPS_ENABLED value="1" }
:if ($oc) do={
  /container envs add list=$envList key=NAS_IDENTIFIER value="socks"
  /container envs add list=$envList key=OCSERV_ENABLED value="1"
  /container envs add list=$envList key=OCSERV_NAS_ID value="ocserv"
  /container envs add list=$envList key=OCSERV_PORT value=$ocPort
  /container envs add list=$envList key=OCSERV_POOL value=$ocPool
  /container envs add list=$envList key=OCSERV_NAT value="0"
  /container envs add list=$envList key=OCSERV_MTU value="1380"
  :if ($acme) do={
    /container envs add list=$envList key=OCSERV_HOST value=$ocHost
    /container envs add list=$envList key=ACME_EMAIL value=$ocEmail
  }
  :if ($n > 0) do={
    /container envs add list=$envList key=OCSERV_LOCATIONS value=$locEnv
    /container envs add list=$envList key=OCSERV_DEFAULT_NAME value=$defName
    :if ([:typeof $tsOcProfile] = "str" and ($tsOcProfile = "no" or $tsOcProfile = "0" or $tsOcProfile = "false")) do={
      /container envs add list=$envList key=OCSERV_PROFILE value="0"
    }
    # Kept for re-installs only (the program does not read it).
    /container envs add list=$envList key=TRAFX_OC_LOCATIONS value=$locSpec
  }
  # /data keeps the certificate and the acme.sh account across updates
  # (Let's Encrypt allows 5 identical certificates a week).
  :if ([:len [/container mounts find where list=$mountList]] = 0) do={
    /container mounts add list=$mountList src=("/" . $disk . "trafx-socks-data") dst=/data comment=$mark
  }
  :set image $ocImage
}

# ---- container ----
# tsImageFile: install from an image tar on the router instead of the registry.
:local imgFile ""
:if ([:typeof $tsImageFile] = "str" and [:len $tsImageFile] > 0) do={
  :if ([:len [/file find where name=$tsImageFile]] = 0) do={ :error ("image file " . $tsImageFile . " not found") }
  :set imgFile $tsImageFile
  :put ("trafx-socks: image from file " . $imgFile)
}
:local rootDir ($disk . "containers/trafx-socks")
:if ([:len $imgFile] > 0) do={
  :if ($oc) do={
    /container add file=$imgFile interface=$vethName envlists=$envList mountlists=$mountList root-dir=$rootDir name=$ctName start-on-boot=yes restart-policy=on-failure stop-time=30s logging=yes
  } else={
    /container add file=$imgFile interface=$vethName envlists=$envList root-dir=$rootDir name=$ctName start-on-boot=yes restart-policy=on-failure stop-time=30s logging=yes
  }
} else={
  :if ($oc) do={
    /container add remote-image=$image interface=$vethName envlists=$envList mountlists=$mountList root-dir=$rootDir name=$ctName start-on-boot=yes restart-policy=on-failure stop-time=30s logging=yes
  } else={
    /container add remote-image=$image interface=$vethName envlists=$envList root-dir=$rootDir name=$ctName start-on-boot=yes restart-policy=on-failure stop-time=30s logging=yes
  }
}
:put "trafx-socks: downloading image"
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

# The secret and license are in the container settings now; drop the globals.
/system script environment remove [find where name~"^ts(Panel|Secret|License|Tunnel|PublicIP|Disk|Port|Http|Https|Ocserv|OcHost|OcEmail|OcPort|OcPool|OcLocations|OcDefaultName|OcProfile|ImageFile)\$"]

:if ($running) do={
  :put ("trafx-socks: running. SOCKS5 " . $publicIP . ":" . $port . " (TCP+UDP). Log: /log print where message~\"trafx\"")
  :if ($http) do={ :put ("trafx-socks: HTTP proxy " . $publicIP . ":" . $port) }
  :if ($https) do={ :put ("trafx-socks: HTTPS proxy " . $ocHost . ":" . $port) }
  :if ($oc) do={
    :local ocAddr $publicIP
    :if ([:len $ocHost] > 0) do={ :set ocAddr $ocHost }
    :put ("trafx-socks: ocserv " . $ocAddr . ":" . $ocPort . " (AnyConnect / OpenConnect). Certificate: /log print where message~\"certificate\"")
  }
} else={
  :put "trafx-socks: did not stay running; see /log print where message~\"trafx\""
}
}
