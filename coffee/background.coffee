local = {}
elResult$ = null
elCtxMenus = null
jsonBookmarks = []
requestInfo = {}
popupWindowId = null
popupWindowLastState = null
focusedWindowId = null
focusedWindowLastState = null
g_folderState = {}
permissionSessions = false

$$ = (selector, parent = document) -> [parent.querySelectorAll(selector)...]

setEventHandlers = ->
  if local.options.postPage
    unless chrome.webRequest.onBeforeRequest.hasListeners()
      chrome.webRequest.onBeforeRequest.addListener onBeforeRequestHandler, urls: ["*://*/*"], ["requestBody"]
    unless chrome.tabs.onRemoved.hasListeners()
      chrome.tabs.onRemoved.addListener onRemoveTabHandler
  else
    if chrome.webRequest.onBeforeRequest.hasListeners()
      chrome.webRequest.onBeforeRequest.removeListener onBeforeRequestHandler
    if chrome.tabs.onRemoved.hasListeners() && !local.options.dispTabs
      chrome.tabs.onRemoved.removeListener onRemoveTabHandler
      requestInfo = {}
  if local.options.dispRecentVisited
    unless chrome.history.onVisited.hasListeners()
      chrome.history.onVisited.addListener changeSpFolderThing
    unless chrome.history.onVisitRemoved.hasListeners()
      chrome.history.onVisitRemoved.addListener changeSpFolderThing
  else
    if chrome.history.onVisited.hasListeners()
      chrome.history.onVisited.removeListener changeSpFolderThing
    if chrome.history.onVisitRemoved.hasListeners()
      chrome.history.onVisitRemoved.removeListener changeSpFolderThing
  if local.options.dispTabs
    unless chrome.tabs.onCreated.hasListeners()
      chrome.tabs.onCreated.addListener changeSpFolderThing
    unless chrome.tabs.onUpdated.hasListeners()
      chrome.tabs.onUpdated.addListener onUpdateTabHandler
    unless chrome.tabs.onMoved.hasListeners()
      chrome.tabs.onMoved.addListener changeSpFolderThing
    unless chrome.tabs.onAttached.hasListeners()
      chrome.tabs.onAttached.addListener changeSpFolderThing
    unless chrome.tabs.onDetached.hasListeners()
      chrome.tabs.onDetached.addListener changeSpFolderThing
    unless chrome.tabs.onRemoved.hasListeners()
      chrome.tabs.onRemoved.addListener onRemoveTabHandler
    unless chrome.tabs.onActivated.hasListeners()
      chrome.tabs.onActivated.addListener changeSpFolderThing
  else
    if chrome.tabs.onCreated.hasListeners()
      chrome.tabs.onCreated.removeListener changeSpFolderThing
    if chrome.tabs.onUpdated.hasListeners()
      chrome.tabs.onUpdated.removeListener changeSpFolderThing
    if chrome.tabs.onMoved.hasListeners()
      chrome.tabs.onMoved.removeListener changeSpFolderThing
    if chrome.tabs.onAttached.hasListeners()
      chrome.tabs.onAttached.removeListener changeSpFolderThing
    if chrome.tabs.onDetached.hasListeners()
      chrome.tabs.onDetached.removeListener changeSpFolderThing
    if chrome.tabs.onRemoved.hasListeners() && !local.options.postPage
      chrome.tabs.onRemoved.removeListener onRemoveTabHandler
    if chrome.tabs.onActivated.hasListeners()
      chrome.tabs.onActivated.removeListener changeSpFolderThing
  if local.options.dispApps || local.options.dispXts
    unless chrome.management.onInstalled.hasListeners()
      chrome.management.onInstalled.addListener changeSpFolderThing
    unless chrome.management.onUninstalled.hasListeners()
      chrome.management.onUninstalled.addListener changeSpFolderThing
    unless chrome.management.onEnabled.hasListeners()
      chrome.management.onEnabled.addListener changeSpFolderThing
    unless chrome.management.onDisabled.hasListeners()
      chrome.management.onDisabled.addListener changeSpFolderThing
  else
    if chrome.management.onInstalled.hasListeners()
      chrome.management.onInstalled.removeListener changeSpFolderThing
    if chrome.management.onUninstalled.hasListeners()
      chrome.management.onUninstalled.removeListener changeSpFolderThing
    if chrome.management.onEnabled.hasListeners()
      chrome.management.onEnabled.removeListener changeSpFolderThing
    if chrome.management.onDisabled.hasListeners()
      chrome.management.onDisabled.removeListener changeSpFolderThing
  unless chrome.windows.onFocusChanged.hasListeners()
    chrome.windows.onFocusChanged.addListener onFocusChangedWindow

getStrFolderState = (folderState) ->
  result = []
  if folderState?.opened
    result.push "opened"
  if folderState?.expanded
    result.push "expanded"
  if folderState?.hide
    result.push "hide"
  result.join(" ")

getFolderState = (strFolderState) ->
  result =
    opened:   /opened/.test(strFolderState)
    expanded: /expanded/.test(strFolderState)
    hide:     /hide/.test(strFolderState)

chrome.permissions.contains {permissions: ["sessions"]}, (granted) ->
  permissionSessions = granted

urlPopup = chrome.runtime.getURL("popup.html")

onClickPopup = (options) ->
  calcTopLeft = ->
    width  = ~~localStorage.windowWidth  || 400
    height = ~~localStorage.windowHeight || 600
    if options.contextMenu
      # top  = Math.min(options.screenY - 10, screen.availHeight - height)
      # left = Math.min(options.screenX - 10, screen.availWidth - width)
      top  = Math.min(options.screenY - 50, screen.availHeight - height)
      left = Math.max(0, options.screenX - width)
    else
      top  = ~~localStorage.windowTop    || 100
      left = ~~localStorage.windowLeft   || 100
    { width, height, top, left }
  updateWindow = (winId) ->
    chrome.windows.update winId, calcTopLeft(), -> dfd.reject()
  createWindow = ->
    windowInfo = Object.assign {}, calcTopLeft(),
      url:  "popup.html"
      type: "popup"
    chrome.windows.create windowInfo, (win) ->
      updateWindow popupWindowId = win.id

  dfd = $.Deferred()
  if popupWindowId
    chrome.windows.get popupWindowId, { populate: true }, (win) ->
      if win
        if options?.contextMenu
          updateWindow win.id
        chrome.windows.update popupWindowId, { focused: true }, (win) ->
          if options?.create
            dfd.resolve()
          else if options?.reload
            chrome.tabs.query { windowId: win.id }, (tabs) ->
              chrome.tabs.reload tabs[0].id
              dfd.resolve()
          else if options.close
            chrome.tabs.query { windowId: win.id }, (tabs) ->
              chrome.tabs.remove tabs[0].id
              dfd.resolve()
      else
        if permissionSessions and not (options.close or options.reload)
          chrome.sessions.getRecentlyClosed {maxResults: chrome.sessions.MAX_SESSION_RESULTS}, (sessions) ->
            sessionFound = false
            for i in [0...sessions.length]
              if win = sessions[i].window
                if win.tabs[0].url is urlPopup
                  chrome.sessions.restore win.sessionId, (restoredSession) ->
                    updateWindow popupWindowId = restoredSession.window.id
                  sessionFound = true
                  break
            unless sessionFound
              if options.close or options.reload
                dfd.resolve()
              else
                createWindow()
        else
          if options.close or options.reload
            dfd.resolve()
          else
            createWindow()
  else
    if options.close or options.reload
      setTimeout (-> dfd.resolve()), 1
    else
      createWindow()
  dfd.promise()

changeStatePopup = ->
  chrome.windows.get focusedWindowId, (win) ->
    if win.state is "minimized"
      chrome.windows.update popupWindowId, { state: "minimized" }
    else
      if focusedWindowLastState is "minimized"
        chrome.windows.update popupWindowId, { state: "normal" }
        chrome.windows.update focusedWindowId, { focused: true }
    focusedWindowLastState = win.state

restorePopupByApp = true
selfMinimized = false
onFocusChangedWindow = (windowId) ->
  if windowId >= 0
    chrome.windows.get windowId, {}, (focusChangedWin) ->
      if chrome.runtime.lastError
        return
      if focusChangedWin?.type is "normal"
        focusedWindowId = windowId
      if local.options.standalone and local.options.restorePanelWin and popupWindowId
        through = false
        chrome.windows.getLastFocused (lastFocusedWin) ->
          # console.log win.type + ": " + win.state
          if lastFocusedWin.type is "normal" and popupWindowLastState is "normal"
            through = true
          chrome.windows.get popupWindowId, (popupWin) ->
            if chrome.runtime.lastError or not popupWin
              return
            popupWindowState = popupWin.state
            if windowId is popupWindowId
              if popupWindowId is lastFocusedWin.id and lastFocusedWin.state is "normal" and lastFocusedWin.type is "normal" and popupWindowState is "minimized"
                selfMinimized = true
              popupWindowLastState = popupWindowState
            else if focusChangedWin?.type is "normal" and popupWindowState is "normal"
              restorePopupByApp = true
            if through
              return
            chrome.windows.getAll {windowTypes: ["normal"]}, (wins) ->
              allMini = true
              for i in [0...wins.length]
                if (win = wins[i]).state isnt "minimized"
                  allMini = false
              if popupWindowState is "minimized"
                unless allMini or selfMinimized
                  chrome.windows.update popupWindowId, { state: "normal", focused: false }, (win) ->
                    restorePopupByApp = true
                    popupWindowLastState = win.state
              else
                if allMini and restorePopupByApp
                  chrome.windows.update popupWindowId, { state: "minimized" }, (win) ->
                    selfMinimized = false
                    restorePopupByApp = false
                    popupWindowLastState = win.state

checkStandalone = ->
  if local.options.standalone
    chrome.browserAction.setPopup { popup: "" }
    unless chrome.browserAction.onClicked.hasListeners()
      chrome.browserAction.onClicked.addListener onClickPopup
  else
    chrome.browserAction.setPopup { popup: "popup.html" }
    if chrome.browserAction.onClicked.hasListeners()
      chrome.browserAction.onClicked.removeListener onClickPopup

chrome.windows.getLastFocused (win) ->
  focusedWindowId = win.id

getActiveTab = ->
  dfd = $.Deferred()
  chrome.tabs.query bmm.getLastWindowQuery(), (tabs) =>
    if tabs.length > 0
      dfd.resolve tabs[0]
    else
      chrome.tabs.query { active: true, windowType: "normal" }, ([tab]) =>
        focusedWindowId = tab.windowId
        dfd.resolve tab
  dfd.promise()

UnescapeUTF8 = (str) ->
  str.replace /%(E(0%[AB]|[1-CEF]%[89AB]|D%[89])[0-9A-F]|C[2-9A-F]|D[0-9A-F])%[89AB][0-9A-F]|%[0-7][0-9A-F]/ig, (s) ->
    c = parseInt(s.substring(1), 16)
    String.fromCharCode if c < 128 then c else if c < 224 then (c & 31) << 6 | parseInt(s.substring(4), 16) & 63 else ((c & 15) << 6 | parseInt(s.substring(4), 16) & 63) << 6 | parseInt(s.substring(7), 16) & 63

window.bmm =
  getGoogleBookmarks: ->
    dfd = $.Deferred()
    $.get("http://www.google.com/bookmarks/lookup", { output: "xml", num: 10000 }, "xml").done (xmlResp) ->
      unless xmlResp.documentElement
        dfd.resolve([], [])
        return
      sites = $$("xml_api_reply > bookmarks > bookmark", xmlResp).map (node) ->
        title: node.querySelector("title").textContent
        url: node.querySelector("url").textContent
        #notes: node.querySelector("notes")?.textContent
        labels: $$("label", node).map (el) -> el.textContent
      labels = _.unique $$("label", xmlResp).map (el) -> el.textContent
      dfd.resolve(sites, labels)
    dfd.promise()
  closeWindow: (newWindowId, tabId, url) ->
    chrome.windows.update focusedWindowId, {focused: true}
  getLastWindowQuery: ->
    result = active: true
    if focusedWindowId #local.options.standalone
      result.windowId = focusedWindowId
    result
  spFolders:
    folders:
      mostVisited:
        disp: "Most visited"
        idName: "spFolderMostVisitedId"
        optName: "dispMostVisited"
        folderName: "db_most"
        iconClassName: "fa fa-star"
        ctxMenu: "menuBookmarkNoEdit"
      recentHistory:
        disp: "Recent History"
        idName: "spFolderRecentHistoryId"
        optName: "dispRecentVisited"
        folderName: "db_recent"
        iconClassName: "fa fa-history"
        ctxMenu: "menuBookmarkHistory"
      recentlyClosed:
        disp: "Recently closed"
        idName: "spFolderRecentlyClosedId"
        optName: "dispRecentlyClosed"
        folderName: "db_closed"
        iconClassName: "fa fa-arrow-circle-left"
        ctxMenu: "menuRecentClose"
      apps:
        disp: "Apps"
        idName: "spFolderAppsId"
        optName: "dispApps"
        folderName: "db_apps"
        iconClassName: "fa fa-th"
        ctxMenu: "menuApps"
      extensions:
        disp: "Extensions"
        idName: "spFolderXtsId"
        optName: "dispXts"
        folderName: "db_xts"
        iconClassName: "fa fa-puzzle-piece"
        ctxMenu: "menuXts"
      tabs:
        disp: "Tabs"
        idName: "spFolderTabsId"
        optName: "dispTabs"
        folderName: "db_tabs"
        iconClassName: "fa fa-folder-o"
        ctxMenu: "menuTabs"
      googleBookmarks:
        disp: "Google Bookmarks"
        idName: "spFolderGoogleId"
        optName: "dispGoogleBookmarks"
        folderName: "db_google"
        iconClassName: "fa fa-google"
        ctxMenu: "menuBookmarkNoEdit"
    checkFolder: ->
      spFolderNames = []
      for key of @folders
        spFolderNames.push @folders[key].folderName
      searchFolder = (node) ->
        if !node.url && node.title in spFolderNames
          chrome.bookmarks.remove node.id
        if node.children
          node.children.forEach (child) ->
            searchFolder child
      chrome.bookmarks.getTree (treeNode) ->
        treeNode.forEach (node) ->
          searchFolder node
    idCleanup: ->
      for key of @folders
        unless local.options[(folder = @folders[key]).optName]
          if id = localStorage[folder.idName]
            chrome.bookmarks.remove id, ->
              localStorage[folder.idName] = null
    setFolderTitle: (id, title) ->
      for key of @folders
        if id is localStorage[(folder = @folders[key]).idName]
          local.folderData[key] = spTitle: title
    getFolderInfo: (id) ->
      for key of @folders
        if id is localStorage[(folder = @folders[key]).idName]
          return _.extend folder,
            title: local.folderData[key]?.spTitle || folder.disp
            className: key
      false
    getFolderInfoByName: (className) ->
      folder = @folders[className]
      Object.assign {}, folder, title: local.folderData[className]?.spTitle || folder.disp
    getKeys: ->
      Object.keys @folders
    createFolders: (dfd) ->
      askOrCreateSpecialFolder = (folderName) ->
        dfd2 = $.Deferred()
        searchFolder = (node) ->
          if !node.url and node.title is folderName
            node.id
          else if node.children
            for i in [0...node.children.length]
              if id = searchFolder(node.children[i])
                break
            id
          else
            null
        chrome.bookmarks.getTree (treeNode) ->
          for i in [0...treeNode.length]
            if spFolderId = searchFolder(treeNode[i])
              break
          if spFolderId
            dfd2.resolve { created: false, id: spFolderId }
          else
            chrome.bookmarks.create { title: folderName, parentId: "1" }, (newNode) ->
              dfd2.resolve { created: true, id: newNode.id }
        dfd2.promise()

      createElAndFolder = (keys, dfd) =>
        if key = keys.pop()
          folder = bmm.spFolders.getFolderInfoByName key
          if local.options[folder.optName]
            askOrCreateSpecialFolder(folder.folderName).done (result) ->
              unless result.created
                elExistsFolder$ = elResult$.find(".folder[data-id='#{result.id}']")
              if result.created || !elExistsFolder$.hasClass("sp")
                folderData = local.folderData[result.id]
                item =
                  id: result.id
                  title: bmm.setAxToTitle folder.title
                  state: getStrFolderState(g_folderState[result.id]) + " sp hidelink " + key
                  padding: 5
                  iconClass: folderData?.icon || folder.iconClassName || "none"
                  folderColor: folderData?.color || "fld1"
                if result.created
                  elResult$.append $(tmplSpFolder(item))
                else
                  elExistsFolder$.replaceWith $(tmplSpFolder(item))
                localStorage[folder.idName] = result.id
              createElAndFolder keys, dfd
          else
            createElAndFolder keys, dfd
        else
          chrome.runtime.sendMessage action: "doneBookmarkThing"
          dfd.resolve()

      createElAndFolder _.keys(@folders), dfd

  getOptions: ->
    return local.options

  getFolderData: (id) ->
    if id
      return local.folderData[id]
    else
      return local.folderData

  setFolderData: (id, obj) ->
    if local.folderData[id]?
      _.extend local.folderData[id], obj
    else
      local.folderData[id] = obj

  getLocal: ->
    return local

  getFolderState: ->
    return g_folderState

  clearFolderState: ->
    g_folderState = {}

  setFolderState: (folderState) ->
    g_folderState = folderState

  getHtml: ->
    elResult$.html()

  getElResult: ->
    elResult$[0].cloneNode true

  getHtmlCtxMenus: ->
    elCtxMenus.cloneNode true

  setPostData: (bmId, postData) ->
    local.postData[bmId] = postData
    saveLocalAndCleanup(true)

  setPanelLoc: (bmId, location) ->
    local.panelLocs[bmId] = location
    saveLocalAndCleanup(true)

  saveLocal: (items) ->
    dfd = $.Deferred()
    setPopupIcon localStorage.markerColor
    local = items
    saveLocalAndCleanup(true).done =>
      unless local.options.memoryFolder
        g_folderState = { "1": { "opened": true, "expanded": true } }
      preMakeHtml()
      dfd.resolve()
    @spFolders.idCleanup()
    checkStandalone()
    setEventHandlers()
    dfd.promise()

  saveDispState: (folderState, searched, query) ->
    if local.options.memoryFolder
      g_folderState = folderState
      localStorage.query = query
      queryU = query.toUpperCase()
      if searched
        elResult$.addClass "searched"
      else
        elResult$.removeClass "searched"
      local.folderState = g_folderState
      saveLocalAndCleanup()
      $.each elResult$.find(".folder"), (i, elFolder) ->
        if id = elFolder.getAttribute "data-id"
          bmm.setFolderStateId g_folderState, elFolder, id
      if queryU?
        $.each elResult$.find(".link"), (i, el) ->
          elLink = el.getElementsByTagName("a")[0]
          if (elLink.getAttribute("title") + elLink.textContent).toUpperCase().indexOf(queryU) >= 0
            el.className = "link"
          else
            el.className = "link hide"
    else
      for key of g_folderState
        g_folderState[key] = {"opened": false, "expanded": false}
      g_folderState["1"] = {"opened": true, "expanded": true}
      if local.options.noDispRoot
        fisrstFolderId = elResult$.find(".folder:first").attr "data-id"
        g_folderState[fisrstFolderId].opened = true
      [elResult$.find(".link.hide")...].forEach (elFolder) ->
        [elFolder.childNodes...].forEach (el) ->
          el.className = "link"

  openBookmark2: (bmId, windowId, baseTabId, index, url, openMode) ->
    sendPostData = (tabId, url, formData, openMode) ->
      chrome.tabs.sendMessage tabId, action: "sendPostData", url: url, data: formData, openMode: openMode
    if formData = local.postData[bmId]
      chrome.tabs.sendMessage baseTabId, action: "hello", (resp) =>
        if resp is "ok"
          sendPostData baseTabId, url, formData, openMode
        else
          chrome.tabs.executeScript baseTabId, file: "postSendAgent.js", (respJs) =>
            sendPostData baseTabId, url, formData, openMode
    else
      if openMode is "openLinkCurrent"
        chrome.tabs.update baseTabId, url: url, (tab) ->
          chrome.windows.update tab.windowId, focused: true
      else
        chrome.tabs.create windowId: windowId, index: index, url: url

  openBookmark: (bmId, openMode) ->
    if openMode is "default"
      if openMode = local.folderData[bmId]?.openMode
        switch openMode
          when "openLinkNewWin", "openLinkSec", "openLinkPopup"
            @openLink bmId, openMode
            return
      else
        if local.options.openNewTab
          openMode = local.options.newTabOpenType || "openLinkNewTab"
        else
          openMode = "openLinkCurrent"
    chrome.bookmarks.get bmId, (treeNodes) =>
      url = treeNodes[0].url
      getActiveTab().done (tab) =>
        baseTabId = tab.id
        if /^javascript:/i.test url
          code = UnescapeUTF8(url)
          chrome.tabs.executeScript baseTabId,
           code: code
           runAt: "document_end"
        else if openMode is "openLinkCurrent"
          @openBookmark2 bmId, null        , baseTabId, null         , url, openMode
        else if openMode is "openLinkNewTab"
          @openBookmark2 bmId, tab.windowId, baseTabId, tab.index + 1, url, openMode
        else
          @openBookmark2 bmId, tab.windowId, baseTabId, 1000         , url, openMode

  targetUrlList: []
  createUrlList: (treeNodes) ->
    for i in [0...treeNodes.length]
      if url = treeNodes[i].url
        @targetUrlList.push {url: url, bmId: treeNodes[i].id}
        if @targetUrlList.length >= ~~local.options.maxOpens
          break
      else
        @createUrlList treeNodes[i].children
    return

  openLink: (bmId, className) ->
    if /openAll|openAllWin|openAllSec/.test className
      @targetUrlList = []
      chrome.bookmarks.getSubTree bmId, (treeNodes) =>
        @createUrlList treeNodes
        if className is "openAll"
          getActiveTab().done (tab) =>
            index = tab.index + 1
            for i in [0...@targetUrlList.length]
              @openBookmark2 @targetUrlList[i].bmId, tab.windowId, tab.id, index++, @targetUrlList[i].url, true
        else
          if className is "openAllSec"
            incognito = true
          else if className is "openAllWin"
            incognito = false
          chrome.windows.create {url: _.pluck(@targetUrlList, "url"), incognito: incognito, focused: true}
    else
      if /openMode/.test className
        className = className.replace(/openMode|user|default/g, "").trim()
        # unless local.folderData[bmId]?.openMode = className
        #   local.folderData[bmId] = openMode: className
      switch className
        when "openLinkCurrent", "openLinkNewTab", "openLinkNewTabRE"
          @openBookmark bmId, className
        when "openLinkNewWin", "openLinkSec", "openLinkPopup"
          chrome.bookmarks.get bmId, (treeNodes) =>
            openInfo =
              url: treeNodes[0].url
              type: windowType = if className is "openLinkPopup" then "detached_panel" else "normal"
              incognito: className is "openLinkSec"
              focused: false
            if windowType is "detached_panel" and local.options.restorePanelWin and panelLocsWk = local.panelLocs[bmId]
              openInfo.width = panelLocsWk.width
              openInfo.height = panelLocsWk.height
              openInfo.top = panelLocsWk.top
              openInfo.left = panelLocsWk.left
            chrome.windows.create openInfo, (win) ->
              if local.options.restorePanelWin and windowType is "detached_panel"
                chrome.windows.update win.id,
                  width: openInfo.width
                  height: openInfo.height
                  left: openInfo.left
                  top: openInfo.top
                  focused: true
                  (win) ->
                    local.panelLocs[win.id] = bmId: bmId

  openUrl: (url, className) ->
    className = className.replace("openMode", "").trim()
    switch className
      when "openLinkCurrent", "openLinkNewTab"
        getActiveTab().done (tab) =>
          if className is "openLinkNewTab"
            chrome.tabs.create windowId: tab.windowId, index: tab.index + 1, url: url
          else
            chrome.tabs.update tab.id, url: url
      when "openLinkNewWin", "openLinkSec", "openLinkPopup"
        windowType = if className is "openLinkPopup" then "detached_panel" else "normal"
        chrome.windows.create {url: url, incognito: className is "openLinkSec", type: windowType, focused: true}

  copyPostData: (orgId, newId) ->
    if postData = local.postData[orgId]
      @setPostData newId, $.extend(true, {}, postData)
    if panelLocsWk = local.panelLocs[orgId]
      @setPanelLoc newId, $.extend(true, {}, panelLocsWk)

  getJsonBookmarks: ->
    return jsonBookmarks

  createBookmark: (parentId, title, url, tabId) ->
    dfd = $.Deferred()
    chrome.bookmarks.create
      parentId: parentId
      title: title
      url: url
      (treeNode) ->
        if local.options.postPage and requestInfo[tabId]?.method is "POST"
          @setPostData bmId, requestInfo[tabId].formData
        dfd.resolve treeNode.id, tabId
    dfd.promise()

  addBookmark: (tabId, parentId, title, url) ->
    @createBookmark(parentId, title, url, tabId)

  addBookmarks: (parentId, tabs) ->
    $.when tabs.map((tab) => @createBookmark(parentId, tab.title, tab.url, tab.id))...
      .done ->
        chrome.runtime.sendMessage action: "changeSpFolderThing"

  makeHtml: (holdState) ->
    elResult$.empty()
    jsonBookmarks = []
    dfd = $.Deferred()
    chrome.bookmarks.getTree (treeNode) =>
      treeNode.forEach (node) =>
        digBookmarks node, elResult$, 0, jsonBookmarks, holdState, "none"
      if local.options.noDispOther
        elResult$.find("div[data-id='2']").remove()
      if !local.options.memoryFolder and local.options.noDispRoot
        fisrstFolderId = (elResult$.find(".folder:first").addClass("opened")).attr "data-id"
        g_folderState[fisrstFolderId].opened = true
      @spFolders.createFolders(dfd)
    dfd.promise()

  createNewWindow: (tabId, incognito, popup) ->
    chrome.windows.create {incognito: incognito, tabId: tabId, type: if popup then "detached_panel" else "normal"}

  setFolderStateId: (folderState, elFolder, id) ->
    newClasses = ["folder"]
    if /sp/.test elFolder.className
      newClasses.push "sp"
      classNames = bmm.spFolders.getKeys()
      for i in [0...classNames.length]
        if elFolder.className.indexOf(classNames[i]) isnt -1
          newClasses.push classNames[i]
          break
    newClasses.push "hasFolder" if /hasFolder/.test(elFolder.getAttribute "class")
    newClasses.push "opened"   if folderState[id]?.opened
    newClasses.push "expanded" if folderState[id]?.expanded
    newClasses.push "hide"     if folderState[id]?.hide
    elFolder.setAttribute "class", newClasses.join(" ")

  createPopup: ->
    onClickPopup create: true

  reloadPopup: ->
    onClickPopup reload: true

  closePopup: ->
    onClickPopup close: true

  rejectAxFromTitle: (title) ->
    if /&/.test title
      title.replace(/&&/g, "^^^").replace(/&/g, "").replace /\^\^\^/g, "&"
    else
      title

  setAxToTitle: (title) ->
    setInitAx = (test) ->
      if re = /^(\d|\w)/.exec test
        test = test.replace /^(\w|\d)/, """<span class="ax">#{re[1]}</span>"""
      test
    if /&/.test title
      test = title.replace /&&/g, "^^^"
      if re = /&(\w|\d)/.exec test
        test = test.replace /&(\w|\d)/, """<span class="ax noinit">#{re[1]}</span>"""
      else
        test = setInitAx(test)
      title = test.replace(/&/g, "").replace /\^\^\^/g, "&"
    else
      title = setInitAx(title)
    title

# End bmm

digBookmarks = (node, parent, indent, folder, holdState, iconClass) ->
  if !node.title #or (node.id is "2" and local.options.noDispOther)
    indent--
    folder.push item = children: []
  else
    item =
      id: node.id
      title: node.title
      url: node.url
    if node.children
      node.padding = indent * 15 + 5
      if holdState
        node.state = getStrFolderState g_folderState[node.id]
      else if node.id is "1"
        node.state = "opened expanded"
      else
        node.state = ""
      g_folderState[node.id] = getFolderState node.state
      if node.id is "1" and local.options.noDispRoot
        indent--
      else
        # spFolderData = null
        # if spFolderData = bmm.spFolders.getFolderInfo(node.id)
        #   node.state += " sp hidelink " + spFolderData.className
        node.title = bmm.setAxToTitle node.title
        if folderData = local.folderData[node.id]
          # node.title = bmm.setAxToTitle spFolderData?.title || node.title
          node.folderColor = folderData?.color || "fld1"
          node.iconClass = folderData?.icon || spFolderData?.iconClassName || "none"
          parent.append newParent = $(tmplSpFolder(node))
        else
          parent.append newParent = $(tmplFolder(node))
        parent = newParent
      item.children = []
    else
      title = bmm.rejectAxFromTitle(node.title)
      if node.url.length > 128
        node.sUrl = title + "\n" + node.url.substring(0, 128) + "..."
      else
        node.sUrl = title + "\n" + node.url
      node.title = bmm.setAxToTitle node.title
      node.indent = indent + 1
      node.iconClass = iconClass
      if /^javascript:/i.test node.url
        parent.append $(tmplLinkJs(node))
      else if local.postData[node.id]
        parent.append $(tmplLinkPosted(node))
      else
        if parent.hasClass("result") and local.options.noDispRoot
          parent.append $(tmplLinkRoot(node))
        else
          parent.append $(tmplLink(node))
    folder.push item
  if node.children #&& !(node.id is "2" and local.options.noDispOther)
    parent.parent().addClass("hasFolder")
    node.children.forEach (child) ->
      digBookmarks child, parent, indent + 1, item.children, holdState, node.iconClass

tmplFolder = _.template """
  <div class="folder <%=state%>" data-id="<%=id%>">
    <div class="marker">
      <span class="expand-icon" style="margin-left:<%=padding%>px"></span><span class="title" tabindex="2"><%=title%></span>
    </div>
  </div>
  """

tmplSpFolder = _.template """
  <div class="folder <%=state%>" data-id="<%=id%>">
    <div class="marker">
      <span class="expand-icon" style="margin-left:<%=padding%>px"></span><span class="title <%=folderColor%>" tabindex="2"><i class="<%=iconClass%>"></i><%=title%></span>
    </div>
  </div>
  """

tmplLink = _.template """
  <div class="link" data-id="<%=id%>">
    <span>
      <a href="#" title="<%=sUrl%>" class="title2" style="background-image:url('chrome://favicon/<%=url%>');"><i class="<%=iconClass%>"></i><%=title%></a>
    </span>
  </div>
  """

tmplLinkRoot = _.template """
  <div class="link" data-id="<%=id%>">
    <span>
      <a href="#" title="<%=sUrl%>" class="title2" style="background-image:url('chrome://favicon/<%=url%>');" tabindex="1"><i class="<%=iconClass%>"></i><%=title%></a>
    </span>
  </div>
  """

tmplLinkJs = _.template """
  <div class="link" data-id="<%=id%>">
    <span>
      <a href="#" title="<%=sUrl%>" class="title2 js"><i class="<%=iconClass%>"></i><%=title%></a>
    </span>
  </div>
  """

tmplLinkPosted = _.template """
  <div class="link" data-id="<%=id%>">
    <span>
      <a href="#" title="<%=sUrl%>" class="title2" style="background-image:url('chrome://favicon/<%=url%>');"><i class="<%=iconClass%>"></i><span class="posted">P</span><%=title%></a>
    </span>
  </div>
  """

taskChainSp = dfdKickerSp = timerSp = null
changeSpFolderThing = ->
  taskChainSp = (taskChainSp || (dfdKickerSp = $.Deferred()).promise()).then ->
    dfdTask = $.Deferred()
    chrome.runtime.sendMessage action: "changeSpFolderThing", {}, (resp) ->
      if dfdTask.state() is "pending"
        dfdTask.reject()
        taskChainSp = dfdKickerSp = null
    if timerSp
      clearTimeout timerSp
    timerSp = setTimeout((->
      if dfdTask.state() is "pending"
        dfdTask.reject()
        taskChainSp = dfdKickerSp = null
    ), 500)
    dfdTask.promise()
  dfdKickerSp.resolve()

taskChain = dfdKicker = null
preMakeHtml = ->
  taskChain = (taskChain || (dfdKicker = $.Deferred()).promise()).then ->
    dfdTask = $.Deferred()
    bmm.makeHtml(true).always ->
      dfdTask.reject()
      taskChain = dfdKicker = null
    dfdTask.promise()
  dfdKicker.resolve()

removeFolderData = (bmIdList) ->
  if bmId = bmIdList.pop()
    chrome.bookmarks.get bmId, (nodes) ->
      if chrome.runtime.lastError or not nodes
        if spFolder = bmm.spFolders.getFolderInfoByName(bmId)
          unless local.options[spFolder.optName]
            delete local.folderData[bmId]
        else
          delete local.folderData[bmId]
      removeFolderData bmIdList

chrome.bookmarks.onCreated.addListener preMakeHtml
chrome.bookmarks.onChanged.addListener preMakeHtml
chrome.bookmarks.onMoved.addListener preMakeHtml
chrome.bookmarks.onChildrenReordered.addListener preMakeHtml
chrome.bookmarks.onImportEnded.addListener preMakeHtml
chrome.bookmarks.onRemoved.addListener ->
  removeFolderData _.keys(local.folderData), dfd = $.Deferred()
  preMakeHtml()

onBeforeRequestHandler = (resp) ->
  if resp.frameId is 0 and resp.type is "main_frame"
    requestInfo[resp.tabId] = method: resp.method
    if local.options.postPage and resp.method is "POST" and resp.requestBody
      requestInfo[resp.tabId].formData = resp.requestBody.formData
  {}

onUpdateTabHandler = (tabId, changeInfo, tab) ->
  if local.options.restorePanelWin and changeInfo.status is "complete" and panelLocsWk = local.panelLocs[tab.windowId]
    chrome.tabs.executeScript tabId,
      code: "window.onbeforeunload=function(){chrome.runtime.sendMessage({action:'closePopup',windowId:#{tab.windowId}})}"
      runAt: "document_end"
  changeSpFolderThing()
  try
    chrome.runtime.sendMessage "action": "hello", (resp) ->
      unless resp is "ok" 
        chrome.tabs.executeScript tabId,
          file: "dbAgent.js"
          runAt: "document_end"
          (respJs) ->
  catch

chainClMsg = null
chrome.runtime.onMessage.addListener (msg) ->
  switch msg.action
    when "closePopup"
      chrome.windows.get msg.windowId, {}, (win) ->
        if panelLocsWk = local.panelLocs[win?.id]
          bmm.setPanelLoc panelLocsWk.bmId,
            width:  win.width
            height: win.height
            top:    win.top
            left:   win.left
    when "mousedown"
      if chainClMsg.state() is "rejected"
         chainClMsg = $.Deferred().resolve()
      chainClMsg = chainClMsg.then -> onClickPopup msg

onRemoveTabHandler = (tabId, removeInfo) ->
  if requestInfo[tabId]
    delete requestInfo[tabId]
  changeSpFolderThing()

setPopupIcon = (markerColor) ->
  canvas = $("""<canvas id="myCanvas" width="19" height="19"></canvas>""")[0]
  ctx = canvas.getContext('2d')
  ctx.fillStyle = "#F6F6F6"
  ctx.beginPath()
  ctx.arc(9.5, 9.5, 8, 0, Math.PI*2, false)
  ctx.closePath()
  ctx.fill()
  ctx.strokeStyle = markerColor
  ctx.lineWidth = 2
  ctx.beginPath()
  ctx.arc(9.5, 9.5, 8.5, 0, Math.PI*2, false)
  ctx.closePath()
  ctx.stroke()
  ctx.fillStyle = "#444444"
  ctx.beginPath()
  ctx.moveTo(6, 5)
  ctx.lineTo(13, 5)
  ctx.lineTo(13, 14)
  ctx.lineTo(9.5, 11)
  ctx.lineTo(6,  14)
  ctx.closePath()
  ctx.fill()
  chrome.browserAction.setIcon path: canvas.toDataURL()

shrinkObj = (shrinkDataFlag, obj) ->
  shrink = (arrBmId, dfd) ->
    if shrinkDataFlag and bmId = arrBmId.pop()
      chrome.bookmarks.get bmId, (nodes) ->
        if chrome.runtime.lastError or not nodes
          delete obj[bmId]
        shrink arrBmId, dfd
    else
      dfd.resolve()
  dfd = $.Deferred()
  shrink _.keys(obj), dfd
  dfd.promise()

saveLocalAndCleanup = (shrinkDataFlag) ->
  dfd = $.Deferred()
  shrinkObj(shrinkDataFlag, local.postData).done ->
    shrinkObj(shrinkDataFlag, local.panelLocs).done ->
      chrome.storage.local.set local, ->
        dfd.resolve()
  dfd.promise()

removePostData = (removePostDataFlag, bmIdList, dfd) ->
  if removePostDataFlag && bmId = bmIdList.pop()
    chrome.bookmarks.get bmId, (nodes) ->
      unless nodes
        delete local.postData[bmId]
      removePostData removePostDataFlag, bmIdList, dfd
  else
    chrome.storage.local.set local, ->
      dfd.resolve()

saveLocalAndCleanup0 = (removePostDataFlag) ->
  removePostData removePostDataFlag, _.keys(local.postData), dfd = $.Deferred()
  dfd.promise()

$ = jQuery
$ ->
  markerColor = localStorage.markerColor || "#87CEEB"
  setPopupIcon markerColor

  elResult$ = $("<div/>", {class: "result"})
  chrome.storage.local.get null, (items) ->
    local = items
    if local.options
      checkStandalone()
      setEventHandlers()
      if local.options.memoryFolder
        g_folderState = local.folderState || {}
        holdState = true
      unless local.panelLocs
        local.panelLocs = {}
    else
      local.options =
        openExclusive: true
        openNewTab: true
        newTabOpenType: "openLinkNewTab"
        memoryFolder: true
        noDispRoot: true
        noDispOther: true
        swapPane: true
        maxOpens: 20
        standalone: false
        postPage: false
        restorePanelWin: false
      local.postData = {}
      local.panelLocs = {}
      chrome.storage.local.set local
      bmm.spFolders.checkFolder()
    unless local.folderData
      local.folderData = {}
    bmm.makeHtml holdState

  elCtxMenus = $(chrome.i18n.getMessage("htmlContextMenus")).get(0)

  chainClMsg = $.Deferred().resolve()
