local json = require("dkjson")


local args = ngx.req.get_post_args()
local action = args and args.action or nil
if action then action = string.untaint(action) end

if action == "disconnect" or action == "connect" or action == "scan" then
  local path = "/tmp/dja-backhaul/web-control/request"
  local f, openerr = io.open(path, "w")
  local success = false

  if f then
    f:write(action .. "\n")
    f:close()
    success = true
  end

  ngx.header.content_type = "application/json"
  ngx.header["Cache-Control"] = "no-store"
  ngx.say(json.encode({
    control = true,
    action = action,
    success = success,
    error = openerr
  }) or "{}")
  ngx.exit(ngx.HTTP_OK)
end

if action == "configure" then
  local ssid = args and args.ssid or nil
  local password = args and args.password or nil
  if ssid then ssid = string.untaint(ssid) end
  if password then password = string.untaint(password) end

  local success = false
  local err = nil

  if not ssid or #ssid < 1 or #ssid > 32 then
    err = "Invalid SSID"
  elseif not password or #password < 8 or #password > 63 then
    err = "Password must be 8-63 characters"
  elseif ssid:find("[\r\n%z]") or password:find("[\r\n%z]") then
    err = "Invalid characters"
  else
    local dir = "/tmp/dja-backhaul/web-control"
    local sf, se = io.open(dir .. "/ssid", "wb")
    if sf then
      sf:write(ssid)
      sf:close()

      local pf, pe = io.open(dir .. "/password", "wb")
      if pf then
        pf:write(password)
        pf:close()

        local rf, re = io.open(dir .. "/request", "w")
        if rf then
          rf:write("configure\n")
          rf:close()
          success = true
        else
          err = re
        end
      else
        err = pe
      end
    else
      err = se
    end
  end

  ngx.header.content_type = "application/json"
  ngx.header["Cache-Control"] = "no-store"
  ngx.say(json.encode({
    control = true,
    action = "configure",
    success = success,
    error = err
  }) or "{}")
  ngx.exit(ngx.HTTP_OK)
end
local data = {connected=false, ssid="", bssid="", rssi="", rate="", channel="", width="", uptime=""}
local fields = {}
local f = io.open("/tmp/dja-backhaul/status-live", "r")
if f then
  for line in f:lines() do
    local k,v = line:match("^([^=]+)=(.*)$")
    if k then fields[k] = v end
  end
  f:close()
end
local clock = io.open("/proc/uptime", "r")
local now
if clock then now = clock:read("*n"); clock:close() end
local sampled = tonumber(fields.sampled_at)
local fresh = now and sampled and now >= sampled and now - sampled <= 20
if fresh then
  data.connected = fields.wpa_state == "COMPLETED"
  data.ssid, data.bssid = fields.ssid or "", fields.bssid or ""
  data.rssi, data.rate = fields.rssi or "", fields.rate or ""
  data.channel = (fields.chanspec or ""):match("^(%d+)") or ""
  data.width = (fields.chanspec or ""):match("^%d+/(%d+)") or ""
  local seconds = tonumber(fields.uptime_seconds)
  if data.connected and seconds and seconds >= 0 then
    seconds = math.floor(seconds)
    data.uptime_seconds = seconds
    local days = math.floor(seconds / 86400)
    data.uptime = (days > 0 and days .. "d " or "") .. string.format("%dh %02dm %02ds", math.floor(seconds / 3600) % 24, math.floor(seconds / 60) % 60, seconds % 60)
  end
end
data.status_available = not not fresh
ngx.header.content_type = "application/json"
ngx.header["Cache-Control"] = "no-store"
ngx.say(json.encode(data) or "{}")
ngx.exit(ngx.HTTP_OK)
