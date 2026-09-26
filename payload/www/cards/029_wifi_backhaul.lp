--pretranslated: do not change this file
gettext.textdomain('webui-core')

local ui_helper=require("web.ui_helper")
local session=ngx.ctx.session
local modalPath=nil

if session:hasAccess("/modals/backhaul-modal.lp") then
  modalPath="/modals/backhaul-modal.lp"
end

ngx.print('\
<div class="span3"><div class="smallcard">\
',ui_helper.createCardHeader(T"Wi-Fi Backhaul",modalPath,nil,nil,{icon={class="icon-rss"}}),'\
<div id="backhaul-card-content" class="content card_bg" data-bg-text="&#xf09e;" style="padding-top:17px;">\
<span class="simple-desc">Getting Backhaul Status...</span>\
</div></div></div>\
<script>\
(function p(){\
  if(!$("#backhaul-card-content").length){return;}\
  $.post("/ajax/backhaul-status.lua",[tch.elementCSRFtoken()],function(d){\
    var e=$("#backhaul-card-content");\
    var esc=function(v){return $("<div>").text(v==null?"":String(v)).html();};\
    if(!d||d.status_available===false){\
      e.html("<span class=\\"simple-desc\\">Backhaul status unavailable</span>");\
    }else if(d.connected){\
      e.html(\
        "<div><div class=\\"light green\\"></div><strong>Backhaul connected</strong></div>"+\
        "<div style=\\"margin-left:17px\\">"+\
          "<div><strong>"+esc(d.ssid||"-")+"</strong></div>"+\
          "<div class=\\"simple-desc\\">"+esc(d.rate||"-")+" &middot; "+esc(d.rssi||"-")+" dBm</div>"+\
          "<div class=\\"simple-desc\\">Ch "+esc(d.channel||"-")+" &middot; "+esc(d.width||"-")+" MHz</div>"+\
          "<div class=\\"simple-desc\\">Uptime "+esc(d.uptime||"-")+"</div>"+\
        "</div>"\
      );\
    }else{\
      e.html(\
        "<div><span style=\\"color:#999\\">○</span> <strong>Not connected</strong></div>"+\
        "<div class=\\"simple-desc\\" style=\\"margin-left:17px\\">Click for Wi-Fi Backhaul</div>"\
      );\
    }\
  },"json").fail(function(){\
    $("#backhaul-card-content").text("Backhaul status unavailable");\
  }).always(function(){setTimeout(p,1000);});\
})();\
</script>\
')
