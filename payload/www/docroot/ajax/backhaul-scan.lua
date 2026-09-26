local json = require("dkjson")
local dm = require("datamodel")
local base = "rpc.wireless.radio.@radio_5G.bsslist."
local items = dm.getPN(base, true) or {}
local networks = {}

for _, item in ipairs(items) do
    if item.path then
        local values = dm.get(item.path) or {}
        local ap = {}

        for _, v in ipairs(values) do
            if v.param then
                ap[v.param] = v.value
            end
        end

        local bssid = item.path:match("@([%x:]+)_radio_5G") or ""
        local ssid = (ap.ssid or ""):gsub("%z", "")

        if ssid ~= "" then
            networks[#networks + 1] = {
                ssid = ssid,
                bssid = bssid,
                rssi = tonumber(ap.rssi) or ap.rssi or "",
                channel = ap.channel or "",
                chanspec = ap.chan_descr or "",
                security = ap.sec or ""
            }
        end
    end
end

table.sort(networks, function(a,b)
    return (tonumber(a.rssi) or -999) > (tonumber(b.rssi) or -999)
end)

ngx.header.content_type = "application/json"
ngx.header["Cache-Control"] = "no-store, no-cache, must-revalidate"

local buffer = {}
if json.encode(networks,{indent=false,buffer=buffer}) then
    ngx.say(table.concat(buffer))
else
    ngx.say("[]")
end

ngx.exit(ngx.HTTP_OK)
