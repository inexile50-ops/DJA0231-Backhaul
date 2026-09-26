local base=arg[1] or '/root/dja-backhaul'
local function read(n) local f=assert(io.open(base..'/'..n,'rb'));local s=f:read('*a');f:close();return s end
local ssid,key,bssid=read('ssid'),read('password'),read('bssid')
assert(#ssid>0 and #ssid<=32,'SSID must be 1-32 bytes')
assert(not key:find('[\r\n%z]'),'Invalid password characters')
local function hex(s)return (s:gsub('.',function(c)return string.format('%02x',string.byte(c))end))end
local psk
if #key==64 then assert(key:match('^[a-fA-F0-9]+$'),'64-character key must be hexadecimal');psk=key
else assert(#key>=8 and #key<=63,'Password must be 8-63 bytes');psk='"'..key:gsub('\\','\\\\'):gsub('"','\\"')..'"' end
if #bssid>0 then assert(#bssid==17 and bssid:match('^%x%x:%x%x:%x%x:%x%x:%x%x:%x%x$'),'Invalid BSSID') end
local text='ctrl_interface=/tmp/dja-backhaul/ctrl\neapol_version=2\nap_scan=2\n'
if #bssid>0 then text=text..'driver_param=bssid='..bssid..'\n' end
text=text..'network={\nssid='..hex(ssid)..'\nproto=RSN\nkey_mgmt=WPA-PSK\npairwise=CCMP\ngroup=CCMP\nieee80211w=0\npsk='..psk..'\n}\n'
if arg[2]=='check' then return end
local f=assert(io.open('/tmp/dja-backhaul/client.conf','w'));f:write(text);f:close()
