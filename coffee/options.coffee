$$ = (selector, parent = document) -> [parent.querySelectorAll(selector)...]

jsonExpData = {}
jsonImpData = {}
local = null
imported = false
bmm = chrome.extension.getBackgroundPage().bmm

onClickOptions = (event) ->
  if $(".settingsView").is(":visible")
    onUnload()
    (dfd = $.Deferred()).promise()
    onSubmitForm(null, dfd)
    dfd.done ->
      folderState = bmm.getFolderState()
      closeAllFolder()
    imported = false
    $(".settingsView").hide()
    $(".result_outer").show()
  else
    $(".settingsView").show()
    $(".result_outer").hide()
    $(".export").val JSON.stringify jsonExpData

onClickExpTab = (event) ->
  newTab = event.currentTarget.className
  unless (currentTab$ = $("div." + newTab)).is(":visible")
    $("div.tabExp,div.tabImp").hide()
    currentTab$.show()
    $(".tabs li").removeClass "current"
    $(".tabs li:has(a.#{newTab})").addClass "current"

importBookmarks = (parentId, children) ->
  children.forEach (child) ->
    preId = child.id
    chrome.bookmarks.create
      parentId: parentId
      title: child.title
      url: child.url
      (newNode) ->
        newId = (newNode?.id || child.id)
        if postData = jsonImpData.postData?[preId]
          bmm.setPostData newId, postData
        importBookmarks newId, child.children if child.children
        imported = true

removeBookmark = (nodes, dfd) ->
  if nodes.length > 0
    chrome.bookmarks.removeTree nodes.pop(), ->
      removeBookmark nodes, dfd
  else
    dfd.resolve()

onClickImport = (event) ->
  try
    jsonImpData = JSON.parse $(".import").val()
    if jsonImpData.bookmarks.length > 0
      if root = jsonImpData.bookmarks[0].children
        if event.currentTarget.className is "impReplace"
          nodes = []
          chrome.bookmarks.getTree (treeNode) ->
            treeNode[0].children.forEach (root) ->
              root.children.forEach (node) ->
                nodes.push node.id
            (dfd = $.Deferred()).promise()
            removeBookmark nodes, dfd
            dfd.done ->
              bmm.clearFolderState()
              importBookmarks "0", root
        else
          bmm.clearFolderState()
          importBookmarks "0", root
  catch e
    alert e.message

onSubmitMain = ->
  $$(".main input[type='checkbox']").forEach (elCheckebox) ->
    local.options[elCheckebox.className] = elCheckebox.checked
  local.options.wheelSense = $(".wheelSense:checked").val()
  local.options.historyCount = $(".historyCount").val()
  local.options.maxOpens = ~~$(".maxOpens").val()
  local.options.newTabOpenType = $("input[name='newTabOpenType']:checked").val()
  localStorage.zoom = $(".zoom").val()
  $$(".main .selectColors").forEach (elColor) ->
    localStorage[elColor.dataset.colorPart] = elColor.value
  bmm.saveLocal(local).done ->
    chrome.tabs.getCurrent (tab) ->
      chrome.windows.get tab.windowId, { populate: true }, (win) ->
        if local.options.standalone
          if win.type is "popup"
            bmm.reloadPopup().done ->
              document.location.reload()
          else
            document.location.reload()
        else
          if win.type is "popup"
            bmm.closePopup().done ->
              query = bmm.getLastWindowQuery()
              query.url = tab.url
              chrome.tabs.create query
              chrome.tabs.remove tab.id
          else
            document.location.reload()
  false

onChangeMarkerColor = (event) ->
  msg = $$(".selectColors").reduce (acc, elColor) ->
    Object.assign acc, [elColor.dataset.colorPart]: elColor.value
  , action: "setColor"
  chrome.runtime.sendMessage msg

onWheelMarkerColor = (event) ->
  colorValue = event.target.value
  curretIndex = markerColors.findIndex ([, value]) -> value is colorValue
  newIndex = curretIndex + Math.sign(event.originalEvent.wheelDelta) + 1
  event.target.value = [markerColors[markerColors.length - 1], markerColors..., [markerColors]][newIndex][1]
  { colorPart } = event.target.dataset
  $("[data-color-part='#{colorPart}']").trigger "change"
  event.preventDefault()
  event.stopPropagation()
  false

onChangeZoom = (event) ->
  chrome.runtime.sendMessage action: "setZoom", zoom: event.target.value
  document.querySelector("iframe.popup").style.zoom = event.target.value / 100

onWheelZoom = (event) ->
  unless document.activeElement is event.target
    if event.originalEvent.wheelDelta > 0
      event.target.value++ if event.target.value < 150
    else
      event.target.value-- if event.target.value > 50
    $(event.target).trigger "change"
    event.preventDefault()
    event.stopPropagation()

onWheelWindow = (event) ->
  if event.target.className is "popup"
    event.preventDefault()
    event.stopPropagation()

setFolderIcon = (req) ->
  folderImgNumber = /fld(\d+)/.exec(req.className)?[1] || "10"
  (dialogIcons$ = $(".dialogIcons"))
    .find(".selected").removeClass("selected").end()
    .find(".folderName").text(req.folderName).attr("data-id", req.bmId).end()
    .find("img[src='css/img/folderOpen#{folderImgNumber}.png']").parent().addClass("selected")
  dialogIcons$.find((req.iconName || "").replace(/^fa\s/, "i.")).parent().addClass("selected")
  if childrenBM = req.childrenBM
    folderColor = "fld" + folderImgNumber
    for i in [0...childrenBM.length]
      unless local.folderData[childrenBM[i]]?["color"] = folderColor
        local.folderData[childrenBM[i]] = color: folderColor

onClickFolderIcon = ->
  (popup$ = $(".popup"))[0].style.zIndex = 3
  dialogIcons$ = $(".dialogIcons").show()
  screen1$ = $(".screen1").show()
  unless dialogIcons$[0].style.left
    # left = screen1$[0].offsetWidth / 2 - dialogIcons$[0].offsetWidth / 2
    top = screen1$[0].offsetHeight / 2 - dialogIcons$[0].offsetHeight / 2
    dialogIcons$[0].style.left = "20px" #left + "px"
    dialogIcons$[0].style.top = top + "px"
  $(".folderIconOuter")[0].style.height = dialogIcons$[0].offsetHeight - 130 + "px"
  if (target$ = $(popup$[0].contentWindow.document.querySelector(".folders .opened"))).length is 1
    marker$ = target$.find("> .marker")
    setFolderIcon
      bmId: target$.attr("data-id")
      className: marker$.find(".title")[0].className
      folderName: marker$.text()
      iconName: marker$.find("i").get(0)?.className
  else
    chrome.runtime.sendMessage action: "getFocusedFolder"
  false

onClickCloseDialog = ->
  $(".popup")[0].style.zIndex = null
  $(".screen1").hide()
  $(".dialogIcons").hide()
  false

onClickDialogIcons = (event) ->
  if event.target.tagName in ["I", "IMG"]
    if (selected$ = $(".dialogIcons .selected")).length > 0
      bmId = $(".dialogIcons .folderName").attr "data-id"
      if event.target.tagName is "I"
        iconClassName = event.target.className
        folderClassName = "fld" + /folderOpen(\d+)\.png/.exec(selected$.find("img")[0].getAttribute("src"))?[1]
      else if event.target.tagName is "IMG"
        unless iconClassName = selected$.find("i").get(0)?.className
          iconClassName = "none"
        folderClassName = "fld" + /folderOpen(\d+)\.png/.exec(event.target.getAttribute("src"))?[1]
      chrome.runtime.sendMessage {action: "changeFolderIcon", data: local.folderData[bmId] = {color: folderClassName, icon: iconClassName}}

gmtAdd = /GMT([+|-]\d{4})/.exec((new Date()).toString())[1] * 36000
syncDataLocal = null
lastSaved = null

loadSyncData = ->
  chrome.storage.sync.get (syncData) =>
    if lastSaved = syncData.saved
      syncDataLocal = {}
      syncDataLocal.options = syncData.options
      syncDataLocal.folderData = syncData.folderData
      syncDataLocal.postData = syncData.postData
      syncDataLocal.panelLocs = syncData.panelLocs
    else
      lastSaved = "None"
    $(".lastSync").text lastSaved

saveSyncData = ->
  saved = (new Date(Date.now()+gmtAdd)).toISOString().substring(0, 19)
  syncDataLocal = "saved": saved
  syncDataLocal.options = local.options
  syncDataLocal.folderData = local.folderData
  syncDataLocal.postData = local.postData
  syncDataLocal.panelLocs = local.panelLocs
  chrome.storage.sync.set syncDataLocal, ->
    if err = chrome.runtime.lastError
      #if /QUOTA_BYTES_PER_ITEM/.test err.message
      #  chkData @saveData.keyConfigSet
      alert err.message
    else
      $(".lastSync").text saved
      chrome.storage.sync.getBytesInUse null, (bytes) ->
        if bytes >= 1000
          bytes = Math.floor(bytes / 1000) + "," + bytes.toString().substr(-3)
        alert "Settings has been saved to Chrome Sync successfully.\n\n• Bytes in use/capacity: #{bytes}/102,400"
        onSubmitMain()

onClickSaveSync = ->
  if lastSaved is "None"
    saveSyncData()
  else
    chrome.storage.sync.clear =>
      if err = chrome.runtime.lastError
        alert err.message
      else
        saveSyncData()

onClickImportSync = ->
  if syncDataLocal
    local.options = syncDataLocal.options
    local.folderData = syncDataLocal.folderData
    local.postData = syncDataLocal.postData
    local.panelLocs = syncDataLocal.panelLocs
    bmm.saveLocal(local).done ->
      onSubmitMain()
      # $("iframe.popup").css(border:0).get(0).contentWindow.document.location.reload()

chrome.runtime.onMessage.addListener (req) ->
  switch req.action
    when "setBodySize"
      unless local.options.standalone
        popup = document.querySelector(".popup")
        popup.style.width = req.width
        popup.style.height = req.height
        popup.style.border = "1px solid #ccc"
        document.querySelector("iframe.popup").zoom = req.zoom
        popup.style.display = "block"
    when "setFocusedFolder"
      setFolderIcon req
    when "readyPopup"
      unless local.options.standalone
        docPopup = document.querySelector(".popup").contentWindow.document
        docPopup.querySelector(".resizeX").style.display = "none"
        docPopup.querySelector(".resizeY").style.display = "none"
        docPopup.querySelector(".resizeR").style.display = "none"

$ = jQuery
$ ->
  i18Messages = JSON.parse "{" + $.trim(chrome.i18n.getMessage("options")) + "}"
  $(document.body).append(tmplMain(i18Messages)).append($(".dialogIcons"))

  manifest = chrome.runtime.getManifest()
  $(".extensionName").text manifest.name
  $(".version").text "v" + manifest.version

  # Colors
  selectColors$ = $(".selectColors")
  markerColors.forEach ([colorName, colorCode]) ->
    selectColors$.append """<option value="#{colorCode}" style="background:#{colorCode}">#{colorName}</option>"""
  selectColors$.on "change", (event) ->
    $(event.target).next(".colorSample1").css background: event.currentTarget.value

  local = bmm.getLocal()
  if local.options.standalone
    bmm.createPopup().done ->
      chrome.tabs.getCurrent (tab) ->
        chrome.windows.create { tabId: tab.id, type: "popup", width: 700 }, ->
  else
    $(".popup").prop "src", "popup.html"

  [$(".main :checkbox")...].forEach (elCheckebox) ->
    elCheckebox.checked = local.options[elCheckebox.className]
  $(".wheelSense[value='#{(local.options.wheelSense || "normal")}']")[0].checked = true
  $("[data-color-part='markerColor']").val color = localStorage.markerColor || "#87CEEB"
  $(".colorSampleMarker").css background: color
  $("[data-color-part='markerColorBkg']").val color = localStorage.markerColorBkg || "#FFFFFF"
  $(".colorSampleBkg").css background: color
  $("[data-color-part='markerColorFont']").val color = localStorage.markerColorFont || "#000000"
  $(".colorSampleFont").css background: color
  $(".zoom").val (localStorage.zoom || 100)
  $(".historyCount").val (local.options.historyCount || 30)
  $(".maxOpens").val (local.options.maxOpens || 20)
  $("input[name='newTabOpenType']").val [local.options.newTabOpenType || "openLinkNewTab"]

  jsonExpData.bookmarks = bmm.getJsonBookmarks()
  jsonExpData.postData  = local.postData
  $(".export").val JSON.stringify jsonExpData

  $(".tabs a").on "click", onClickExpTab
  $(".main").on "submit", onSubmitMain
  $(".selectColors")
    .on("mousewheel", onWheelMarkerColor)
    .on("change", onChangeMarkerColor)
  $(".zoom")
    .on("mousewheel", onWheelZoom)
    .on("change", onChangeZoom)
  $(".saveSync").on "click", onClickSaveSync
  $(".impSync").on "click", onClickImportSync
  $(".impReplace,.impAppend").on "click", onClickImport
  $(".folderIcon").on "click", onClickFolderIcon
  $(".btnCloseDialog").on "click", onClickCloseDialog
  $(".dialogIcons").on "click", onClickDialogIcons
  $(".openNewTab").on "click", (ev) ->
    if $(ev.target).is(":checked")
      $("input[name='newTabOpenType']").prop("disabled", false).parent().removeClass("disabled")
    else
      $("input[name='newTabOpenType']").prop("disabled", true).parent().addClass("disabled")
  # $(".btnSave").on "click", onClickSave
  $(window).on "mousewheel", onWheelWindow

  chrome.permissions.contains {permissions: ["sessions"]}, (granted) ->
    unless granted
      $(".dispRecentlyClosed").removeAttr("checked").attr("disabled", "disabled")

  $(".main").show(50)

  $(".dialogIcons").draggable {cancel: "img,i"}
  # Colors
  folderColors$ = $(".folderColors")
  for i in [0..18]
    folderColors$.append """<span><img src="css/img/folderOpen#{i+1}.png"></span>"""

  # Icons
  $.get("font-awesome/fonts/font-list2.txt").done (out) ->
    folderIcons = out.split("\n")
    folderIcons$ = $(".folderIcons")
    folderIcons.reduce (tr$, className, i) ->
      td$ = """<td><i class="fa #{className}" title="#{className}"></i></td>"""
      if i % 18 is 0
        $("<tr/>").append(td$).appendTo folderIcons$
      else
        tr$.append td$
    , null
    .append """<td colspan="3"><i class="none">None</i></td>"""
    #folderIcons2$.on "change", (event) ->

  loadSyncData()

tmplMain = _.template """
  <div class="settingsView">
    <div class="header">
      <h5><span class="extensionName"></span> options <span class="version"></span></h5>
    </div>
    <form class="main">
      <button class="btnSave btn btn-primary">Save</button>
      <div class="heading"><%=general%></div>
      <label><input type="checkbox" class="openNewTab"><%=openNewTab%></label>
        <dd>
          <label><input type="radio" name="newTabOpenType" value="openLinkNewTab"> - <%=openRight%></label>
          <label><input type="radio" name="newTabOpenType" value="openLinkNewTabRE"> - <%=openRightEnd%></label>
        </dd>
      <label><input type="checkbox" class="openExclusive" checked><%=openExclusive%></label>
      <label><input type="checkbox" class="memoryFolder" checked><%=memoryFolder%></label>
      <label><input type="checkbox" class="noDispRoot"><%=noDispRoot%></label>
      <label><input type="checkbox" class="noDispOther"><%=noDispOther%></label>
      <label><input type="checkbox" class="standalone"><%=standalone%></label>
      <label class="form-inline"><%=maxOpens%>: <input type="number" min="1" max="200" value="20" class="maxOpens form-control"></label>
      <div class="heading"><%=advanced%></div>
      <label style="display:none;"><input type="checkbox" class="preSearch"><%=preSearch%></label>
      <label><input type="checkbox" class="postPage"><%=postPage%></label>
      <label><input type="checkbox" class="restorePanelWin"><%=restorePanelWin%></label>
      <div class="heading"><%=exterior%></div>
      <label><input type="checkbox" class="swapPane"><%=swapPane%></label>
      <label class="form-inline"><%=zoom%>: <input type="number" min="50" max="150" value="100" class="zoom form-control"> %</label>
      <table>
        <tr>
          <td>
            <label class="floating" for=".markerColor"><%=markerColor%>:</label>
          </td>
          <td class="form-inline">
            <div class="colorSample1 colorSampleMarker"></div>
            <select data-color-part="markerColor" class="selectColors form-control"></select>
          </td>
        </tr>
        <tr>
          <td>
            <label class="floating" for=".markerColorBkg"><%=markerColorBkg%>:</label>
          </td>
          <td class="form-inline">
            <div class="colorSample1 colorSampleBkg"></div>
            <select data-color-part="markerColorBkg" class="selectColors form-control"></select>
          </td>
        </tr>
        <tr>
          <td>
            <label class="floating" for=".markerColorFont"><%=markerColorFont%>:</label>
          </td>
          <td class="form-inline">
            <div class="colorSample1 colorSampleFont"></div>
            <select data-color-part="markerColorFont" class="selectColors form-control"></select>
          </td>
        </tr>
      </table>
      <label>
        <button class="folderIcon btn btn-secondary btn-sm"><i class="fa fa-folder-open-o"></i> <%=setFolderIcon%></button>
      </label>
      <div class="heading"><%=addonFolder%></div>
      <label><input type="checkbox" class="dispGoogleBookmarks">Google Bookmarks</label>
      <label><input type="checkbox" class="dispMostVisited"><%=dispMostVisited%></label>
      <label class="form-inline"><input type="checkbox" class="dispRecentVisited"><%=dispRecentVisited%>: <input type="number" min="5" max="200" value="30" class="historyCount form-control"> <%=counting%></label>
      <label><input type="checkbox" class="dispRecentlyClosed"><%=dispRecentlyClosed%></label>
      <label><input type="checkbox" class="dispTabs"><%=dispTabs%></label>
      <dd><label><%=tabsCaution%></label></dd>
      <dd><label>- <input type="checkbox" class="focusLinkTab"><%=focusLinkTab%></label></dd>
      <dd><label>- <input type="checkbox" class="hoverLinkTab"><%=hoverLinkTab%></label></dd>
      <label><input type="checkbox" class="dispApps"><%=dispApps%></label>
      <label><input type="checkbox" class="dispXts"><%=dispXts%></label>
      <div class="heading"><%=mouse%></div>
      <label><input type="checkbox" class="noWheelLoop"><%=noWheelLoop%></label>
      <label><input type="checkbox" class="noWheelLoopBM"><%=noWheelLoopBM%></label>
      <label><%=wheelSense%>:
        <label><input type="radio" class="wheelSense" name="wheelSense" value="normal" checked="checked"><%=wheelSenseNrm%></label>
        <label><input type="radio" class="wheelSense" name="wheelSense" value="slow"><%=wheelSenseSlow%></label>
      </label>
      <div style="display:none">
        <div>
          <div class="heading"><%=syncSetsCaption%></div>
          <label>Last saved: <span class="lastSync"></span></label>
          <label>
            <button class="saveSync small"><i class="fa fa-cloud-upload"></i> <%=saveSync%></button>
            <button class="impSync orange small"><i class="fa fa-cloud-download"></i> <%=importSync%></button>
          </label>
        </div>
        <div class="heading"><%=expimp%></div>
        <ul class="tabs">
          <li class="current"><a class="tabExp"><%=tabExp%></a></li>
          <li><a class="tabImp"><%=tabImp%></a></li>
        </ul>
        <div class="tabExp"> <%=expDataCaption%>
          <textarea class="export" readonly="readonly"></textarea>
        </div>
        <div class="tabImp" style="display:none"> <%=expDataCaption%> <!--<button class="clear small">Clear</button>-->
          <textarea class="import"></textarea>
          <button class="impAppend small"><i class="fa fa-plus"></i> <%=impAppend%></button>
          <button class="impReplace small"><i class="fa fa-download"></i> <%=impReplace%></button>
        </div>
      </div>
    </form>
    <div class="dialogIcons">
      <button class="btnCloseDialog btn btn-secondary btn-sm">Close</button>
      <span class="dialogTitle"><%=setFolderIcon.replace('...', '')%> - </span>
      <span class="folderName"></span>
      <div class="caption">Color:</div>
      <div class="folderColors"></div>
      <div class="caption">Icon:</div>
      <div class="folderIconOuter">
        <table class="folderIcons"></table>
      </div>
    </div>
  </div>
  """

markerColors = [
  ["White" ,"#FFFFFF"]
  ["Snow" ,"#FFFAFA"]
  ["GhostWhite" ,"#F8F8FF"]
  ["WhiteSmoke" ,"#F5F5F5"]
  ["FloralWhite" ,"#FFFAF0"]
  ["Linen" ,"#FAF0E6"]
  ["AntiqueWhite" ,"#FAEBD7"]
  ["PapayaWhip" ,"#FFEFD5"]
  ["BlanchedAlmond" ,"#FFEBCD"]
  ["Bisque" ,"#FFE4C4"]
  ["Moccasin" ,"#FFE4B5"]
  ["NavajoWhite" ,"#FFDEAD"]
  ["PeachPuff" ,"#FFDAB9"]
  ["MistyRose" ,"#FFE4E1"]
  ["LavenderBlush" ,"#FFF0F5"]
  ["Seashell" ,"#FFF5EE"]
  ["OldLace" ,"#FDF5E6"]
  ["Ivory" ,"#FFFFF0"]
  ["Honeydew" ,"#F0FFF0"]
  ["MintCream" ,"#F5FFFA"]
  ["Azure" ,"#F0FFFF"]
  ["AliceBlue" ,"#F0F8FF"]
  ["Lavender" ,"#E6E6FA"]
  ["Black" ,"#000000"]
  ["DarkSlateGray" ,"#2F4F4F"]
  ["DimGray" ,"#696969"]
  ["Gray" ,"#808080"]
  ["DarkGray" ,"#A9A9A9"]
  ["Silver" ,"#C0C0C0"]
  ["LightGrey" ,"#D3D3D3"]
  ["Gainsboro" ,"#DCDCDC"]
  ["WindowFrame" ,"#F6F6F6"]
  ["LightSlateGray" ,"#778899"]
  ["SlateGray" ,"#708090"]
  ["LightSteelBlue" ,"#B0C4DE"]
  ["SteelBlue" ,"#4682B4"]
  ["RoyalBlue" ,"#4169E1"]
  ["MidinightBlue" ,"#191970"]
  ["Navy" ,"#000080"]
  ["DarkBlue" ,"#00008B"]
  ["MediumBlue" ,"#0000CD"]
  ["Blue" ,"#0000FF"]
  ["DodgerBlue" ,"#1E90FF"]
  ["CornflowerBlue" ,"#6495ED"]
  ["DeepSkyBlue" ,"#00BFFF"]
  ["LightSkyBlue" ,"#87CEFA"]
  ["SkyBlue" ,"#87CEEB"]
  ["LightBlue" ,"#ADD8E6"]
  ["PowderBlue" ,"#B0E0E6"]
  ["PaleTurquoise" ,"#AFEEEE"]
  ["LightCyan" ,"#E0FFFF"]
  ["Aqua" ,"#00FFFF"]
  ["Turquoise" ,"#40E0D0"]
  ["MediumTurquoise" ,"#48D1CC"]
  ["DarkTurquoise" ,"#00CED1"]
  ["LightSeaGreen" ,"#20B2AA"]
  ["CadetBlue" ,"#5F9EA0"]
  ["Darkcyan" ,"#008B8B"]
  ["Teal" ,"#008080"]
  ["SeaGreen" ,"#2E8B57"]
  ["DarkOliveGreen" ,"#556B2F"]
  ["DarkGreen" ,"#006400"]
  ["Green" ,"#008000"]
  ["ForestGreen" ,"#228B22"]
  ["MediumSeaGreen" ,"#3CB371"]
  ["DarkSeaGreen" ,"#8FBC8F"]
  ["MideumAquamarine" ,"#66CDAA"]
  ["Aquamarine" ,"#7FFFD4"]
  ["PaleGreen" ,"#98FB98"]
  ["LightGreen" ,"#90EE90"]
  ["SpringGreen" ,"#00FF7F"]
  ["MediumSpringGreen" ,"#00DA9A"]
  ["LawnGreen" ,"#7CFC00"]
  ["Chartreuse" ,"#7FFF00"]
  ["GreenYellow" ,"#ADFF2F"]
  ["Lime" ,"#00FF00"]
  ["LimeGreen" ,"#32CD32"]
  ["YellowGreen" ,"#9ACD32"]
  ["OliveDrab" ,"#6B8E23"]
  ["Olive" ,"#808000"]
  ["DarkKhaki" ,"#BDB76B"]
  ["PaleGoldenrod" ,"#EEE8AA"]
  ["Cornsilk" ,"#FFF8DC"]
  ["Beige" ,"#F5F5DC"]
  ["LightYellow" ,"#FFFFE0"]
  ["LightGoldenrodYellow" ,"#FAFAD2"]
  ["LemonChiffon" ,"#FFFACD"]
  ["Wheat" ,"#F5DEB3"]
  ["Burywood" ,"#DEB887"]
  ["Tan" ,"#D2B48C"]
  ["Khaki" ,"#F0E68C"]
  ["Yellow" ,"#FFFF00"]
  ["Gold" ,"#FFD700"]
  ["Orange" ,"#FFA500"]
  ["SandyBrown" ,"#F4A460"]
  ["DarkOrange" ,"#FF8C00"]
  ["Golodenrod" ,"#DAA520"]
  ["Peru" ,"#CD853F"]
  ["DarkGoldenrod" ,"#B8860B"]
  ["Chocolate" ,"#D2691E"]
  ["Sienna" ,"#A0522D"]
  ["SaddleBrown" ,"#8B4513"]
  ["Maroon" ,"#800000"]
  ["DarkRed" ,"#8B0000"]
  ["Brown" ,"#A52A2A"]
  ["FireBrick" ,"#B22222"]
  ["IndianRed" ,"#CD5C5C"]
  ["RosyBrown" ,"#BC8F8F"]
  ["DarkSalmon" ,"#E9967A"]
  ["LightCoral" ,"#F08080"]
  ["Salmon" ,"#FA8072"]
  ["LightSalmon" ,"#FFA07A"]
  ["Coral" ,"#FF7F50"]
  ["Tomato" ,"#FF6347"]
  ["OrangeRed" ,"#FF4500"]
  ["Red" ,"#FF0000"]
  ["Crimson" ,"#DC143C"]
  ["MediumVioletRed" ,"#C71585"]
  ["DeepPink" ,"#FF1493"]
  ["HotPink" ,"#FF69B4"]
  ["PaleVioletRed" ,"#DB7093"]
  ["Pink" ,"#FFC0CB"]
  ["LightPink" ,"#FFB6C1"]
  ["Thistle" ,"#D8BFD8"]
  ["Magenta" ,"#FF00FF"]
  ["Violet" ,"#EE82EE"]
  ["Plum" ,"#DDA0DD"]
  ["Orchid" ,"#DA70D6"]
  ["MediumOrchid" ,"#BA55D3"]
  ["DarkOrchid" ,"#9932CC"]
  ["DarkViolet" ,"#9400D3"]
  ["DarkMagenta" ,"#8B008B"]
  ["Purple" ,"#800080"]
  ["Indigo" ,"#4B0082"]
  ["DarkSlateBlue" ,"#483D8B"]
  ["BlueViolet" ,"#8A2BE2"]
  ["MediumPurple" ,"#937CDB"]
  ["SlateBlue" ,"#6A5ACD"]
  ["MediumSlateBlue" ,"#7B68EE"]
]
