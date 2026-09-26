--pretranslated: do not change this file

gettext.textdomain('webui-core')

local ui_helper=require("web.ui_helper")

ngx.print(ui_helper.createHeader(T"Wi-Fi Backhaul",true,true))

ngx.print([[
<div class="modal-body update">

<style>
#save-config { display: none !important; }
#bh-toolbar {
  margin-bottom: 12px;
  white-space: nowrap;
}
#bh-toolbar .bh-title {
  display: inline-block;
  width: 170px;
  text-align: center;
}
#bh-count {
  margin-left: 8px;
}
#bh-list {
  max-height: 330px;
  overflow-y: auto;
}
#bh-table {
  width: 100%;
  margin-bottom: 0;
}
#bh-table th,
#bh-table td {
  padding: 7px 8px;
  vertical-align: middle;
}
#bh-table .bh-network {
  width: 38%;
}
#bh-table .bh-signal {
  width: 17%;
}
#bh-table .bh-channel {
  width: 25%;
}
#bh-table .bh-security {
  width: 20%;
}
#bh-table tbody tr {
  cursor: pointer;
}
.bh-dot {
  display: inline-block;
  width: 17px;
}
.bh-current {
  color: #5cb85c;
}
.bh-selected.bh-connecting { opacity: 0.15; }
.bh-selected {
  color: #f0ad4e;
}
#backhaul-connect-panel {
  margin-top: 14px;
}
</style>

<div id="bh-toolbar">
  <span class="bh-title">Wireless Networks</span>
  <button id="backhaul-scan" class="btn">
    <i class="icon-refresh"></i> Scan
  </button>
  <button id="backhaul-connect" class="btn" disabled>
    Connect to AP
  </button>
  <button id="backhaul-disconnect" class="btn">Disconnect</button>
  <span id="bh-count"></span>
</div>

<div id="bh-list">
<table id="bh-table" class="table table-striped">
<thead>
<tr>
  <th class="bh-network">Network</th>
  <th class="bh-signal">Signal</th>
  <th class="bh-channel">Channel</th>
  <th class="bh-security">Security</th>
</tr>
</thead>
<tbody id="backhaul-networks">
<tr>
  <td colspan="4"></td>
</tr>
</tbody>
</table>
</div>

<div id="backhaul-connect-panel" style="display:none">
  <hr>
  <h4>Connect Backhaul</h4>
  <p>
    Selected network:
    <strong id="backhaul-selected-ssid"></strong>
  </p>

  <label for="backhaul-password">Wi-Fi password</label>
  <input type="password"
         id="backhaul-password"
         autocomplete="new-password">

  <p style="margin-top:10px">
    <button id="backhaul-cancel" class="btn">Cancel</button>
    <button id="backhaul-connect-final"
            class="btn btn-primary"
            disabled>
      Connect Backhaul
    </button>
  </p>
</div>

</div>

<script>
var backhaulScanNetworks=[];
var selectedBackhaulIndex=-1;
var currentBackhaulBssid="";
var backhaulProgressTimer=null;
var backhaulConnectPulseTimer=null;
var backhaulConnectButtonTimer=null;

function bh(v){
  return $("<div>").text(v==null?"":String(v)).html();
}

function bhMarker(current,selected){
  if(selected)
    return '<span class="bh-dot bh-selected">●</span>';

  if(current)
    return '<span class="bh-dot bh-current">●</span>';

  return '<span class="bh-dot">○</span>';
}

function bhRender(){
  var body=$("#backhaul-networks").empty();

  if(!backhaulScanNetworks.length){
    body.append(
      '<tr><td colspan="4">No networks found.</td></tr>'
    );
    return;
  }

  $.each(backhaulScanNetworks,function(i,ap){
    var current=
      currentBackhaulBssid!=="" &&
      (ap.bssid||"").toLowerCase()===currentBackhaulBssid;

    var selected=(i===selectedBackhaulIndex);

    var channel=bh(ap.channel||"-");

    if(ap.chanspec)
      channel+=" ("+bh(ap.chanspec)+")";

    body.append(
      '<tr class="backhaul-ap-select" data-index="'+i+'">'+
        '<td class="bh-network">'+
          '<span class="backhaul-marker">'+
            bhMarker(current,selected)+
          '</span>'+
          bh(ap.ssid||"Unknown network")+
        '</td>'+
        '<td class="bh-signal">'+
          bh(ap.rssi||"-")+' dBm'+
        '</td>'+
        '<td class="bh-channel">'+
          channel+
        '</td>'+
        '<td class="bh-security">'+
          bh(ap.security||"-")+
        '</td>'+
      '</tr>'
    );
  });
}

function bhConnectButtonStop(){ if(backhaulConnectButtonTimer){ clearInterval(backhaulConnectButtonTimer); backhaulConnectButtonTimer=null; } }
function bhConnectButtonStart(b){ bhConnectButtonStop(); var dots=1; b.text("Connecting."); backhaulConnectButtonTimer=setInterval(function(){ dots=dots%3+1; b.text("Connecting"+"...".substring(0,dots)); },250); }
function bhConnectPulseStop(){ if(backhaulConnectPulseTimer){ clearInterval(backhaulConnectPulseTimer); backhaulConnectPulseTimer=null; } $("#backhaul-networks .bh-selected").removeClass("bh-connecting"); }
function bhConnectPulseStart(index){ bhConnectPulseStop(); var dot=$("#backhaul-networks tr").filter("[data-index="+index+"]").find(".bh-selected"); backhaulConnectPulseTimer=setInterval(function(){ dot.toggleClass("bh-connecting"); },250); }
function bhProgressStart(text){
  if(backhaulProgressTimer) clearInterval(backhaulProgressTimer);
  var dots=1;
  $("#backhaul-disconnect").text(text+".");
  backhaulProgressTimer=setInterval(function(){
    dots=dots%3+1;
    $("#backhaul-disconnect").text(text+"...".substring(0,dots));
  },500);
}
function bhProgressStop(){
  if(backhaulProgressTimer){ clearInterval(backhaulProgressTimer); backhaulProgressTimer=null; }
}

function bhUpdateState(updateControl){
  $.post("/ajax/backhaul-status.lua",[tch.elementCSRFtoken()],function(d){
    currentBackhaulBssid=(d&&d.bssid?d.bssid:"").toLowerCase();
    $("#backhaul-scan").prop("disabled",!!(d&&d.connected));
    if(updateControl) $("#backhaul-disconnect").text(d&&d.connected?"Disconnect":"Reconnect").prop("disabled",false);
  },"json");
}
function bhWaitForState(wantConnected){
  var tries=0;
  (function check(){
    $.post("/ajax/backhaul-status.lua",[tch.elementCSRFtoken()],function(d){
      var connected=!!(d&&d.connected);
      currentBackhaulBssid=(d&&d.bssid?d.bssid:"").toLowerCase();
      $("#backhaul-scan").prop("disabled",connected);
      if(connected===wantConnected){
        bhProgressStop();
        $("#backhaul-disconnect").text(connected?"Disconnect":"Reconnect").prop("disabled",false);
      }else if(++tries<20){
        setTimeout(check,1000);
      }else{
        bhProgressStop();
        bhUpdateState(true);
      }
    },"json");
  })();
}



$("#backhaul-scan").click(function(){
  var button=$(this);

  button.prop("disabled",true);
  $("#bh-count").text("Scanning.");

  $.post("/ajax/backhaul-status.lua",[tch.elementCSRFtoken(),{name:"action",value:"scan"}],function(result){
    if(!result || !result.success){
      $("#bh-count").text("Scan could not be started.");
      bhUpdateState(false);
      return;
    }

    var scanTries=0;
    (function readScan(){
      setTimeout(function(){
        $.getJSON("/ajax/backhaul-scan.lua?_="+Date.now(),function(data){
          data=$.isArray(data)?data:[];
          if(data.length===0 && ++scanTries<15){ $("#bh-count").text("Scanning"+"...".substring(0,(scanTries%3)+1)); readScan(); return; }
          backhaulScanNetworks=data;
          selectedBackhaulIndex=-1;
          $("#backhaul-connect").prop("disabled",true);
          $("#bh-count").text(data.length+" network"+(data.length===1?"":"s")+" found");
          bhRender();
          bhUpdateState(false);
        }).fail(function(){
          if(++scanTries<15){ readScan(); return; }
          $("#bh-count").text("Could not read scan results.");
          bhUpdateState(false);
        });
      },1000);
    })();
  }).fail(function(){
    $("#bh-count").text("Scan could not be started.");
    bhUpdateState(false);
  });
});

$("#backhaul-networks").on(
  "click",
  ".backhaul-ap-select",
  function(){

    var index=parseInt($(this).attr("data-index"),10);

    if(isNaN(index) || !backhaulScanNetworks[index])
      return;

    selectedBackhaulIndex=index;

    bhRender();

    $("#backhaul-connect").prop("disabled",false);
  }
);

$("#backhaul-connect").click(function(){
  if(selectedBackhaulIndex<0 ||
     !backhaulScanNetworks[selectedBackhaulIndex])
    return;

  var ap=backhaulScanNetworks[selectedBackhaulIndex];

  $("#backhaul-selected-ssid")
    .text(ap.ssid||"Unknown network");

  $("#backhaul-password").val("");

  $("#backhaul-connect-final")
    .prop("disabled",true);

  $("#backhaul-connect-panel").show();

  $("#backhaul-password").focus();
});

$("#backhaul-cancel").click(function(){
  $("#backhaul-connect-panel").hide();
  $("#backhaul-password").val("");
  $("#backhaul-connect-final").prop("disabled",true);
});

$("#backhaul-password").on("input",function(){
  $("#backhaul-connect-final")
    .prop("disabled",$(this).val().length<8);
});

$("#backhaul-connect-final").click(function(){
  if(selectedBackhaulIndex<0 ||
     !backhaulScanNetworks[selectedBackhaulIndex])
    return;

  var ap=backhaulScanNetworks[selectedBackhaulIndex];
  var password=$("#backhaul-password").val();
  var b=$(this);

  if(!ap.ssid || password.length<8)
    return;

  b.prop("disabled",true); bhConnectButtonStart(b);
  bhConnectPulseStart(selectedBackhaulIndex);

  $.post(
    "/ajax/backhaul-status.lua",
    [
      tch.elementCSRFtoken(),
      {name:"action",value:"configure"},
      {name:"ssid",value:ap.ssid},
      {name:"password",value:password}
    ],
    function(d){
      if(d&&d.control&&d.success){
        $("#backhaul-connect-panel").hide();
        $("#backhaul-password").val("");
        b.text("Connect Backhaul").prop("disabled",true);
        $("#bh-count").text("Connecting to "+ap.ssid+"...");
        var checks=0;
        var checkConnected=function(){
          $.post("/ajax/backhaul-status.lua",[tch.elementCSRFtoken()],function(s){
            if(s&&s.connected&&s.ssid===ap.ssid){
              bhConnectPulseStop();
              bhConnectButtonStop();
              currentBackhaulBssid=(s.bssid||"").toLowerCase();
              $("#backhaul-scan").prop("disabled",true);
              selectedBackhaulIndex=-1;
              bhRender();
              $("#bh-count").text("Connected to "+ap.ssid);
              $("#modal-changes").addClass("hide");
              $("#modal-no-change").removeClass("hide");
              return;
            }
            if(++checks<45)
              setTimeout(checkConnected,2000);
            else { bhConnectPulseStop(); bhConnectButtonStop(); $("#bh-count").text("Connection timed out."); b.text("Connect Backhaul").prop("disabled",false); }
          },"json").fail(function(){
            if(++checks<45)
              setTimeout(checkConnected,2000);
            else { bhConnectPulseStop(); bhConnectButtonStop(); $("#bh-count").text("Connection timed out."); b.text("Connect Backhaul").prop("disabled",false); }
          });
        };
        setTimeout(checkConnected,2000);
      }else{
        b.text("Connect Backhaul").prop("disabled",false);
        bhConnectPulseStop();
        bhConnectButtonStop();
        alert("Backhaul configuration failed"+(d&&d.error?": "+d.error:""));
      }
    },
    "json"
  ).fail(function(){
    b.text("Connect Backhaul").prop("disabled",false);
    bhConnectPulseStop();
    bhConnectButtonStop();
    alert("Backhaul configuration request failed");
  });
});
$(document).off("click.backhaulControl","#backhaul-disconnect").on("click.backhaulControl","#backhaul-disconnect",function(){
  var b=$(this);
  var reconnect=b.text()=="Reconnect";
  var action=reconnect?"connect":"disconnect";
  b.prop("disabled",true); bhProgressStart(reconnect?"Connecting":"Disconnecting");
  $.post("/ajax/backhaul-status.lua",[tch.elementCSRFtoken(),{name:"action",value:action}],function(d){
    if(d&&d.control&&d.success){
      bhWaitForState(reconnect);
    }else{
      bhProgressStop();
      b.text(reconnect?"Reconnect":"Disconnect").prop("disabled",false);
      alert("Backhaul "+action+" failed"+(d&&d.error?": "+d.error:""));
    }
  },"json").fail(function(){
    bhProgressStop();
    b.text(reconnect?"Reconnect":"Disconnect").prop("disabled",false);
    alert("Backhaul "+action+" request failed");
  });
});
bhUpdateState(true);
</script>
]])

ngx.print(ui_helper.createFooter())
