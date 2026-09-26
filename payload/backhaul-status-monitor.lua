-- Backhaul telemetry sampler and privileged WebUI control worker.
local function read(command)
  local p = io.popen("/usr/bin/timeout 2 " .. command .. " 2>/dev/null")
  if not p then return "" end
  local s = p:read("*a") or ""
  p:close()
  return s
end
local function monotonic()
  local f = assert(io.open("/proc/uptime"))
  local n = tonumber(f:read("*n"))
  f:close()
  return math.floor(n)
end
local function control()
  local dir = "/tmp/dja-backhaul/web-control"
  local path = dir .. "/request"
  local f = io.open(path, "r")
  if not f then return end
  local action = f:read("*l") or ""
  f:close()
  os.remove(path)

  if action == "disconnect" then
    os.execute([[ubus call service delete '{"name":"dja-backhaul","instance":"backhaul"}' >/dev/null 2>&1]])
  elseif action == "connect" then
    os.execute("/etc/init.d/dja-backhaul start")
  elseif action == "scan" then
    os.execute("ubus call wireless.radio.acs rescan '{\"name\":\"radio_5G\",\"act\":1}' >/dev/null 2>&1")
  elseif action == "configure" then
    local function take(name)
      local p = dir .. "/" .. name
      local h = io.open(p, "rb")
      if not h then return nil end
      local v = h:read("*a") or ""
      h:close()
      os.remove(p)
      return v
    end

    local ssid = take("ssid")
    local password = take("password")
    if not ssid or not password then return end

    if #ssid < 1 or #ssid > 32 then return end
    if #password < 8 or #password > 63 then return end
    if ssid:find("[\r\n%z]") or password:find("[\r\n%z]") then return end

    local function put(name, value)
      local p = "/root/dja-backhaul/" .. name .. ".new"
      local h = assert(io.open(p, "wb"))
      assert(h:write(value))
      assert(h:close())
      assert(os.rename(p, "/root/dja-backhaul/" .. name))
    end

    put("ssid", ssid)
    put("password", password)
    put("bssid", "")
    os.execute("chmod 600 /root/dja-backhaul/ssid /root/dja-backhaul/password /root/dja-backhaul/bssid")
    os.execute("/etc/init.d/dja-backhaul restart")
  end
end

local function sample()
  local stamp = monotonic()
  local status = read("/root/dja-backhaul/bin/wpa_cli -p /tmp/dja-backhaul/ctrl -i wl1_3 status")
  local fields = {}
  for k,v in status:gmatch("([%w_]+)=([^\r\n]*)") do fields[k] = v end
  local state = "DISCONNECTED"
  local age, rssi, rate, chanspec = "", "", "", ""
  local bssid = fields.bssid or ""
  if fields.wpa_state == "COMPLETED" and bssid:match("^%x%x:%x%x:%x%x:%x%x:%x%x:%x%x$") then
    local station = read("/usr/bin/wl -i wl1_3 sta_info " .. bssid)
    local flags = station:match("state:([^\r\n]+)") or ""
    if flags:match("%f[%a]ASSOCIATED%f[%A]") and flags:match("%f[%a]AUTHORIZED%f[%A]") then
      state = "COMPLETED"
      age = station:match("in network%s+(%d+)%s+seconds") or ""
      rssi = read("/usr/bin/wl -i wl1_3 rssi"):match("%-?%d+") or ""
      rate = read("/usr/bin/wl -i wl1_3 rate"):match("([^\r\n]+)") or ""
      chanspec = read("/usr/bin/wl -i wl1_3 chanspec"):match("([^\r\n]+)") or ""
    end
  end
  local output = {
    "wpa_state=" .. state, "ssid=" .. (fields.ssid or ""), "bssid=" .. bssid,
    "rssi=" .. rssi, "rate=" .. rate, "chanspec=" .. chanspec,
    "uptime_seconds=" .. age, "sampled_at=" .. stamp
  }
  local path = "/tmp/dja-backhaul/status-live"
  local f = assert(io.open(path .. ".new", "w"))
  assert(f:write(table.concat(output, "\n") .. "\n"))
  assert(f:close())
  assert(os.rename(path .. ".new", path))
end
repeat
  control()
  sample()
  if arg[1] == "--once" then break end
  os.execute("sleep 1")
until false
