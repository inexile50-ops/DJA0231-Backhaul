--pretranslated: do not change this file
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local js_chart_rgb_helper = require("js_chart_rgb_helper")
local rgb = js_chart_rgb_helper.getRGB("wanup")

local attributes = {
  header = {
    style = "color:rgb("..rgb..");"
  }
}

ngx.print('\
<div class="span3">\
  <div class="smallcard chartcard">\
    <div class="chartdata" style="color:rgb('); ngx.print(rgb); ngx.print(')"><span id="backup_data">0.00</span><span class="unit">Mb/s</span></div>\
    '); ngx.print(ui_helper.createCardHeader(T"Backhaul Upload",nil,nil,nil,attributes)); ngx.print('\
    <div class="content card_bg" data-bg-text="&#xf0ee;">\
      <canvas id="backup_canvas"></canvas>\
    </div>\
  </div>\
</div>\
<script>\
$().ready(function(){\
  var ctx=document.getElementById("backup_canvas").getContext("2d");\
  var cfg={\
    type:"line",\
    data:{\
      labels:[60,58,56,54,52,50,48,46,44,42,40,38,36,34,32,30,28,26,24,22,20,18,16,14,12,10,8,6,4,2],\
      datasets:[{\
        borderWidth:1,\
        borderColor:"rgb('); ngx.print(rgb); ngx.print(')",\
        backgroundColor:"rgba('); ngx.print(rgb); ngx.print(',0.25)",\
        data:[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],\
        fill:true,\
        pointRadius:0\
      }]\
    },\
    options:{\
      events:[],\
      maintainAspectRatio:false,\
      legend:{display:false},\
      scales:{\
        xAxes:[{display:false}],\
        yAxes:[{display:false,ticks:{min:0}}]\
      }\
    }\
  };\
  window.backup_chart=new Chart(ctx,cfg);\
  var prevBytes=null;\
  var prevTime=null;\
  function poll(){\
    $.post("/ajax/backhaul-status.lua",[tch.elementCSRFtoken()],function(d){\
      var now=Date.now();\
      var bytes=Number(d.tx_bytes||0);\
      var mbps=0;\
      if(prevBytes!==null && prevTime!==null && now>prevTime){\
        var delta=bytes-prevBytes;\
        if(delta>=0){\
          mbps=(delta*8)/((now-prevTime)*1000);\
        }\
      }\
      prevBytes=bytes;\
      prevTime=now;\
      $("#backup_data").text(mbps.toFixed(2));\
      var a=window.backup_chart.data.datasets[0].data;\
      a.shift();\
      a.push(mbps);\
      window.backup_chart.update(0);\
    },"json").always(function(){setTimeout(poll,2000);});\
  }\
  poll();\
});\
</script>\
');
