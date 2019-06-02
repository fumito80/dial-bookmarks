elResult$ = null
focused$  = null
g_currentId = null
g_droppedId = null
copiedBmId = null
dfdSubmitQueue = null
dfdSetSpFolderQueue = null
virtualClick = false

$$ = (selector, parent = document) -> [parent.querySelectorAll(selector)...]

coalesceAllFolder = ->
  for key of bmm.folderState
    bmm.folderState[key].opened = false
    bmm.folderState[key].expanded = false

closeAllFolder = ->
  for key of bmm.folderState
    bmm.folderState[key].opened = false

openAllFolder = ->
  for key of bmm.folderState
    bmm.folderState[key].opened = true
    bmm.folderState[key].expanded = true
  setFolderState()

setFolderState = (id) ->
  if id
    $$(".folder[data-id='#{id}']").forEach (folder) ->
      bmm.setFolderStateId bmm.folderState, folder, id
  else
    $$(".folder").forEach (folder) ->
      if id = folder.dataset.id
        bmm.setFolderStateId bmm.folderState, folder, id
  bmm.setScrollIntoView()
  bmm.onScrollFolders document.querySelector(".folders")

sortBeforeIndex = 0
sortPlaceholder = null
sortDropped = false
dropOvers = 0

initCtxMenu = ->
  $(".folders .folder:not(.sp):not(.virtual) > .marker > .title").contextMenu("menuFolder", {})
  $(".folders .folder.sp:not(.virtual) > .marker > .title").contextMenu("none", {})
  $(".bookmks .folder:not(.sp):not(.virtual) .link a").contextMenu("menuBookmark", {})
  $(".folders .googleBookmarks .title").contextMenu("menuFolderGoogle", {})
  $(".folders .virtual .title").contextMenu("menuFolderGoogleLabel", {})
  $(".folders .result > .link a").contextMenu("menuBookmark", {})
  $(".folders .folder.apps > .marker > .title").contextMenu("menuFolderApps", {})
  $(".folders .folder.extensions > .marker > .title").contextMenu("menuFolderExtensions", {})
  $(".folders .folder.recentHistory > .marker > .title").contextMenu("menuFolderHistory", {})
  $(".folders .folder.recentlyClosed > .marker > .title").contextMenu("menuFolderRecentClose", {})
  $(".folders .folder.tabs > .marker > .title").contextMenu("menuFolderTabs", {})
  $(".folders .folder.mostVisited > .marker > .title").contextMenu("menuFolderMostVisited", {})
  $(".result_outer").contextMenu("menuFolderRoot", {})

elDragMoving = document.querySelector ".dragMoving"
dragMoving = (event) ->
  elDragMoving.style.left = event.x + 15 + document.body.scrollLeft + "px"
  elDragMoving.style.top = event.y + 8 + document.body.scrollTop + "px"

elExtDisabled = document.querySelector ".extDisabled"

initSortableTabs = ->
  target$ = $(".bookmks .folder.sp.tabs")
  try
    target$.sortable "refresh"
    return false
  catch
    setBookmarksSortable target$, (event, ui) ->
      if dataValue = ui.item.find("a").get(0).dataset.value
        tabId = dataValue.split(":")[1]
        newTarget$ = ui.item.prev()
        unless /link/.test newTarget$.attr("class")
          newTarget$ = ui.item.next()
        windowId = newTarget$.find("a").get(0).dataset.value.split(":")[0]
        targetTabs = []
        $.each ui.item.parent().children(".folder,.link"), (i, el) ->
          dataValue = $(el).find("a").get(0).dataset.value
          ids = dataValue.split(":")
          if ids[0] is windowId or ids[1] is tabId
            targetTabs.push(ids[1])
        index = 0
        $.each targetTabs, (i, id) ->
          if id is tabId
            index = i
            return false
        chrome.tabs.move ~~tabId, {windowId: ~~windowId, index: index}, (newTab) ->
          unless newTab
            target$.sortable "cancel"
    return true

initSortableApps = (type) ->
  target$ = $(".bookmks .folder.sp." + type)
  try
    target$.sortable "refresh"
    return false
  catch
    setBookmarksSortable target$, (event, ui) ->
      $.each ui.item.parent().children(".folder,.link"), (i, el) ->
        appId = $(el).find("a").get(0).dataset.value
        options.appsOrder[appId] = i + 1
    return true

initSortable = (target, targetType) ->
  $(".folders .folder:not(.sp):not(.virtual) > .marker > .title:not(.ui-droppable)").droppable
    accept: ".link[data-id!='none'],.folder"
    hoverClass: "ui-state-hover"
    tolerance: "pointer"
    drop: (event, ui) ->
      sortDropped = true
      if linkId = (srcTarget = ui.draggable.get(0)).dataset.id
        currentId = $(event.target).parent().parent().get(0).dataset.id
        chrome.bookmarks.get linkId, (nodes) ->
          unless nodes[0].parentId is currentId
            ui.draggable.remove()
          chrome.bookmarks.move linkId, parentId: currentId
          if /folder/.test srcTarget.className
            g_droppedId = currentId
          else
            g_currentId = currentId
    over: (event, ui) ->
      if ++dropOvers
        sortPlaceholder?.style.display = "none"
    out: (event, ui) ->
      unless --dropOvers
        sortPlaceholder?.style.display = ""
  try
    $(target).sortable "refresh"
    return false
  catch
    if targetType is "bookmark"
      setBookmarksSortable $(target), (event, ui) ->
        linkId = ui.item.get(0).dataset.id
        unless parentId = ui.item.parent().get(0).dataset.id
          return
        # g_currentId = parentId
        index = ui.item.parent().children(".folder,.link").index(ui.item)
        if sortBeforeIndex < index
          index++
        chrome.bookmarks.move linkId, {index: index}
      if options.noDispRoot
        $(target).sortable {connectWith: ".folders .result"}
    else
      setFoldersSortable $(target)
      if options.noDispRoot
        $(target).sortable {connectWith: ".folders .result"}
    setFoldersSortable $(".folders .result")
    return true

setBookmarksSortable = (target$, fnUpdate) ->
  target$.sortable
    handle: ".title2"
    items: "> .link"
    helper: "clone"
    placeholder: "ui-placeholder-folder"
    delay: 100
    start: (event, ui) ->
      sortDropped = false
      sortPlaceholder = document.querySelector(".ui-placeholder-folder")
      sortPlaceholder.style.display = ""
      dropOvers = 0
      sortBeforeIndex = ui.item.parent().children(".folder,.link").index(ui.item)
      document.addEventListener "mousemove", dragMoving, false
      ui.helper.css "position", "fixed"
    stop: (event, ui) ->
      sortPlaceholder.style.display = "none"
      sortPlaceholder = null
      ui.item.removeAttr("style")
      $(elDragMoving).hide()
      document.removeEventListener "mousemove", dragMoving, false
    update: fnUpdate

setFoldersSortable = (target$) ->
  target$.sortable
    handle: "> .marker > .title,.title2"
    items: "> .folder[data-id!='1'][data-id!='2'],> .link"
    delay: 100
    helper: "clone"
    placeholder: "ui-placeholder-folder"
    start: (event, ui) ->
      $(".folders").addClass("sorting")
      sortDropped = false
      sortPlaceholder = document.querySelector(".folders .ui-placeholder-folder")
      sortPlaceholder.style.display = ""
      dropOvers = 0
      ui.helper.removeClass("opened").find(".opened").removeClass "opened"
      document.addEventListener "mousemove", dragMoving, false
    stop: (event, ui) ->
      $(".folders").removeClass("sorting")
      sortPlaceholder.style.display = "none"
      sortPlaceholder = null
      ui.item.removeAttr("style")
      $(elDragMoving).hide()
      document.removeEventListener "mousemove", dragMoving, false
    update: (event, ui) ->
      $(".folders").removeClass("sorting")
      unless sortDropped
        targetId = ui.item.attr("data-id")
        if prevId = ui.item.prevAll("div:first").get(0)?.dataset.id
          chrome.bookmarks.get prevId, (nodes) ->
            chrome.bookmarks.move targetId, {parentId: nodes[0].parentId, index: nodes[0].index + 1}, (newNode) ->
              # g_currentId = newNode.id
        else
          unless parentId = ui.item.parent().get(0).dataset.id
            parentId = "1"
          chrome.bookmarks.move targetId, {parentId: parentId, index: 0}, (newNode) ->
            # g_currentId = newNode.id

window.resizeScrollBar = ->
  $(".result_outer").getNiceScroll().resize()

reloadState = ->
  elResult$.html bmm.getHtml()
  if g_currentId
    for key of bmm.folderState
      bmm.folderState[key].opened = false
    bmm.folderState[g_currentId].opened = true
    bmm.folderState[g_currentId].expanded = true
    g_currentId = null
    setFolderState()
  if g_droppedId
    bmm.folderState[g_droppedId].expanded = true
    g_droppedId = null
    setFolderState()
  resizeScrollBar()
  if elResult$.hasClass "searched"
    initCtxMenu()
    onSubmitForm()
  else
    setTimeout((->
      initCtxMenu()
    ), 500)

enableSortable = ->
  $(".result").removeClass "searched"
  try
    $(".bookmks .folder.ui-sortable").sortable "enable"
    $(".folders .folder.ui-sortable").sortable "enable"
  catch

hideCtxMenu = ->
  $("#jqContextMenu,#jqContextMenuShadow").hide()

getSelected = ->
  hideCtxMenu()
  selected = document.querySelector(".selected")
  if selected and not selected.dataset
    return selected.querySelector('.title2')
  selected

getUrlFromFavicon = (faviconUrl) ->
  url = /url\("?chrome:\/\/favicon\/(.+?)"?\)$/.exec(faviconUrl)[1]

onClickAddFolder = ->
  if (folderName = window.prompt(chrome.i18n.getMessage("newFolder"), ""))
    target = getSelected()
    g_droppedId = (target$ = $(target)).parent().parent().get(0)?.dataset.id || "1"
    chrome.bookmarks.create
      parentId: g_droppedId
      title: folderName
    target$.removeClass("selected")

onClickEditTitle = (ev) ->
  if ev and /disabled/.test(ev.target.className)
    return
  if target = getSelected()
    id = (target$ = $(target)).parent().parent().get(0)?.dataset.id
    if id in ["1", "2", "3"]
      return
    else
      hideCtxMenu()
      if target.tagName is "A"
        caption = chrome.i18n.getMessage("editBookmarkName")
      else
        caption = chrome.i18n.getMessage("editFolderName")
      if folderName = window.prompt(caption, target.textContent)
        g_droppedId = target$.parent().parent().parent().get(0)?.dataset.id
        if /sp/.test target$.parent().parent().get(0)?.className
          bmm.spFolders.setFolderTitle id, folderName
          bmm.makeHtml true
        else
          chrome.bookmarks.update id,
            title: folderName
    target$.removeClass "selected"
  hideCtxMenu()

onClickEditUrl = ->
  if target = getSelected()
    id = (target$ = $(target)).parent().parent().get(0)?.dataset.id
    url = getUrlFromFavicon(target.style.backgroundImage)
    caption = chrome.i18n.getMessage("editURL")
    if newUrl = window.prompt(caption, url)
      g_droppedId = target$.parent().parent().parent().get(0)?.dataset.id
      chrome.bookmarks.update id,
        url: newUrl
    target$.removeClass "selected"

onClickDelete = (ev) ->
  if ev and /disabled/.test(ev.target.className)
    return
  if target = getSelected()
    id = (target$ = $(target)).parent().parent().get(0)?.dataset.id
    if id in ["1", "2", "3"]
      return
    else
      hideCtxMenu()
      g_currentId = target$.parent().parent().parent().get(0)?.dataset.id
      chrome.bookmarks.getChildren id, (treeNodes) ->
        if treeNodes.length > 0
          caption = chrome.i18n.getMessage("deleteConfirm", target.textContent)
          if confirm caption
            chrome.bookmarks.removeTree id
        else
          chrome.bookmarks.remove id
        target$.removeClass "selected"
  hideCtxMenu()

onClickAddBookmark = (event) ->
  target = getSelected()
  g_currentId = (target$ = $(target)).parent().parent().get(0)?.dataset.id || "1"
  query = bmm.getLastWindowQuery()
  unless event.target.className is "addBookmark"
    query.highlighted = true
    delete query.active
  chrome.tabs.query query, (tabs) ->
    if tabs.length > 1
      bmm.addBookmarks g_currentId, tabs
    else
      caption = chrome.i18n.getMessage("newBookmark")
      if title = window.prompt(caption, tabs[0].title)
        bmm.addBookmark tabs[0].id, g_currentId, title, tabs[0].url
  target$.removeClass "selected"

switchFolderState = ->
  if target = $(".folder.opened:first").get(0)
    id = target.dataset.id
    if bmm.folderState[id]
      bmm.folderState[id].expanded = !bmm.folderState[id].expanded
    else
      bmm.folderState[id].expanded = true
      bmm.folderState[id].opened = false
    setFolderState()

sendToSettingsFolderInfo = (target, elTitle) ->
  chrome.runtime.sendMessage
    action: "setFocusedFolder"
    bmId: target.dataset.id
    className: elTitle.className
    folderName: elTitle.textContent
    iconName: $(elTitle).find("i").get(0)?.className

onFocusFolder = (event) ->
  enableSortable()
  target = event.currentTarget.parent().parent().get(0)
  id = target.dataset.id
  for key of bmm.folderState
    bmm.folderState[key].opened = false
  if bmm.folderState[id]
    bmm.folderState[id].opened = true
  else
    bmm.folderState[id].expanded = false
    bmm.folderState[id].opened = true
  setFolderState()
  bmm.setSpecialFolders([target]).done ->
    selectAxFolder($(target)) if axKeyMode
  resizeScrollBar()
  sendToSettingsFolderInfo target, event.currentTarget[0]

onKeyUpQuery = (event) ->
  if event.target.value is ""
    $(".fa-times").hide()
  else
    $(".fa-times").show()

axKeyMode = 0
onKeydownQuery = (event) ->
  unless event.keyCode in [9, 13, 18, 27, 37, 38, 39, 40]
    if event.altKey or axKeyMode > 0
      return
    setTimeout((->
      $("form").submit()
    ), 0)
    event.stopPropagation()

onSubmitForm = (event, holdState) ->
  dfdSubmitQueue = dfdSubmitQueue.then ->
    bmm.dfdQueryCommit = $.Deferred()
    unless (elResult$ = $(".result")).hasClass("searched") or bmm.lastFolderState
      bmm.lastFolderState = $.extend true, {}, bmm.folderState
    elResult$.addClass "searched"
    try
      $(".bookmks .folder.ui-sortable").sortable "disable"
      $(".folders .folder.ui-sortable").sortable "disable"
    catch
    if (query = $("input.query").focus().val()) is ""
      onClickRemoveQuery()
      bmm.dfdQueryCommit.resolve()
    else
      bmm.query(query)
    bmm.dfdQueryCommit.promise()
  false

onClickRemoveQuery = (event) ->
  $(".query").val("").focus()
  event?.target.style.display = "none"
  if (opened$ = $(".folders .opened")).length isnt 1 or not options.memoryFolder
    bmm.folderState = bmm.lastFolderState
  for key of bmm.folderState
    bmm.folderState[key].hide = false
  setFolderState()
  bmm.setFolderState bmm.folderState
  $$(".link.hide").forEach (link) ->
    link.className = "link" + if /active/.test(link.className) then " active" else ""
  $(".result").removeClass("searched")
  bmm.lastFolderState = null
  resizeScrollBar()

onWindowUnload = (ev) ->
  localStorage.axKeyMode = axKeyMode
  if window is window.parent
    bmm.saveDispState bmm.folderState, $(".result").hasClass("searched"), $("input.query").val(), options.appsOrder
    if options.standalone
      localStorage.windowTop = window.screenTop
      localStorage.windowLeft = window.screenLeft
      localStorage.windowWidth = window.outerWidth
      localStorage.windowHeight = window.outerHeight

wheelBuf = 0
onWheelWindow = (event) ->
  if axKeyMode
    setAxKeyMode 0
  getNext$ = (targetParent$, focused$, targetName, direction, loopEnd) ->
    index = (targets$ = targetParent$.find(targetName + ":visible")).index(focused$) + direction
    if (nextEl$ = targets$.eq(index)).length > 0
      if ((options.noWheelLoop && targetName is ".folder") || (options.noWheelLoopBM && targetName is ".link")) and index is -1
        nextEl$ = null
    else
      if (options.noWheelLoop && targetName is ".folder") || (options.noWheelLoopBM && targetName is ".link")
        nextEl$ = null
      else
        nextEl$ = targetParent$.find(targetName + ":visible" + loopEnd)
    nextEl$

  if event.originalEvent.wheelDelta > 0
    if wheelBuf > 0
      wheelBuf = -1
    else
      wheelBuf--
    direction = -1
    loopEnd = ":last"
  else
    if wheelBuf < 0
      wheelBuf = 1
    else
      wheelBuf++
    direction = 1
    loopEnd = ":first"

  if options.wheelSense isnt "slow" or (wheelBuf > 1 or wheelBuf < -1)
    wheelBuf = 0
    hideCtxMenu()
    $(".selected").removeClass "selected"
    if (focused$ = $("a:focus")).length > 0
      if nextEl$ = getNext$ $(".bookmks"), focused$.parent().parent(), ".link", direction, loopEnd
        nextEl$.find("a").focus()
    else
      if (focused$ = $(".folders .opened")).length > 0
        if focused$.length is 1
          nextEl$ = getNext$ $(".folders"), focused$, ".folder", direction, loopEnd
        else
          nextEl$ = focused$.filter(":first")
      else
        nextEl$ = $(".folders .folder:visible:first")
      if nextEl$
        onFocusFolder currentTarget: nextEl$.removeClass("opened").find(".title:visible:first")

onClickWindow = (event) ->
  if virtualClick
    virtualClick = false
  else if axKeyMode
    setAxKeyMode 0
  target = if event.target?.className is "ax" or event.target?.localName is "i"
    event.target.parentElement
  else
    event.target
  unless className = target?.className
    return
  if /expand-icon/.test className
    expanded = (target$ = $(target).parent().parent()).hasClass("expanded")
    id = target$[0].dataset.id
    if bmm.folderState[id]
      bmm.folderState[id].expanded = false
    else
      bmm.folderState[id].expanded = false
      bmm.folderState[id].opened = false
    unless expanded
      bmm.folderState[id].expanded = true
    setFolderState(id)
    event.stopPropagation()
  else if /title2/.test className
    if event.which is 2 and target.tagName is "A"
      return false
    else
      if linkType = target.dataset.key
        openApp = false # extension or *packaged_app and enabled
        if target.dataset.type is "hosted_app"
          openApp = true
        else if /packaged_app/.test(target.dataset.type) and not /disabled/.test(className)
          openApp = true
        openSpLink linkType, target.dataset.value, openApp
      else if (id = $(target).parent().parent().get(0)?.dataset.id) is "none"
        imageUrl = target.style.backgroundImage
        openSpLink "link", imageUrl, if options.openNewTab then "openLinkNewTab" else "openLinkCurrent"
      else
        bmm.openBookmark id, "default" #options.openNewTab
      unless linkType in ["xts", "tab", "app"]
        bmm.closeWindow()
  else if /title/.test (className + target.parentElement?.className)
    visible = (target$ = $(target).parents(".folder:first")).hasClass("opened")
    if (bookmarks$ = $(".result")).hasClass "searched"
      enableSortable()
      visible = false
    allSet = id = target$.get(0).dataset.id
    if options.openExclusive
      coalesceAllFolder()
    else
      closeAllFolder()
    $.each target$.parents(".folder"), (i, el) ->
      pid = el.dataset.id
      bmm.folderState[pid].expanded = true
    allSet = null
    if visible
      bmm.folderState[id].opened = false
      bmm.folderState[id].expanded = false
    else
      if bmm.folderState[id]
        bmm.folderState[id].opened = true
        bmm.folderState[id].expanded = true
      else
        bmm.folderState[id] = opened: true, expanded: true
      bmm.setSpecialFolders([target$.get(0)]).done ->
        selectAxFolder(target$) if axKeyMode
    setFolderState(allSet)
    resizeScrollBar()
    sendToSettingsFolderInfo target$.get(0), target

mouseStateDown = false
onMouseUpWindow = (event) ->
  mouseStateDown = false
  $(elDragMoving).hide()
  if mouseDownTimer
    clearTimeout mouseDownTimer
  if mouseDownTimer2
    clearTimeout mouseDownTimer2
  if /panel1|bookmarks|result|link|folder|marker/.test event.target.className
    if event.which in [2, 3]
      if focused$
        focused$.click()
      else
        if event.which is 3
          switchFolderState()
        else # which is 2
          if !elResult$.hasClass("searched") and (tabs$ = $(".bookmks .tabs.opened")).length is 1
            chrome.tabs.query bmm.getLastWindowQuery(), (tabs) ->
              tabs$.find("a[data-value='#{tabs[0].windowId}:#{tabs[0].id}']:visible").focus()
          else
            $(".bookmks a:visible:first").focus()
            return
  document.querySelector(".query").focus()

mouseDownTimer = null
mouseDownTimer2 = null
onMouseDnWindow = (event) ->
  mouseStateDown = true
  if /title/.test event.target.className
    sortableTarget = event.target.parentElement.parentElement.parentElement
    if /title2/.test event.target.className
      targetType = "bookmark"
    else
      targetType = "folder"
    if event.which is 1 and !$(".folders .fa-times").is(":visible") and !elResult$.hasClass("searched")
      if !/sp|virtual/.test(sortableTarget.className) and !/^\d$|none/.test(event.target.parentElement.parentElement.getAttribute("data-id"))
        mouseDownTimer = setTimeout((->
          if initSortable(sortableTarget, targetType)
            mousedownEvent = document.createEvent "MouseEvent"
            mousedownEvent.initMouseEvent("mousedown", true, true, window, 0,
              event.screenX, event.screenY, event.clientX, event.clientY,
              event.ctrlKey, event.altKey, event.shiftKey, event.metaKey,
              0, null)
            event.target.dispatchEvent mousedownEvent
        ), 1)
        mouseDownTimer2 = setTimeout((->
          if mouseStateDown
            $(elDragMoving).show()
            elDragMoving.style.left = event.clientX + 15 + document.body.scrollLeft + "px"
            elDragMoving.style.top = event.clientY + 8 + document.body.scrollTop + "px"
        ), 100)
      else if /sp\stabs/.test sortableTarget.className
        mouseDownTimer = setTimeout((->
          if initSortableTabs()
            mousedownEvent = document.createEvent "MouseEvent"
            mousedownEvent.initMouseEvent("mousedown", true, true, window, 0,
              event.screenX, event.screenY, event.clientX, event.clientY,
              event.ctrlKey, event.altKey, event.shiftKey, event.metaKey,
              0, null)
            event.target.dispatchEvent mousedownEvent
        ), 1)
        mouseDownTimer2 = setTimeout((->
          if mouseStateDown
            $(elDragMoving).show()
            elDragMoving.style.left = event.clientX + 15 + document.body.scrollLeft + "px"
            elDragMoving.style.top = event.clientY + 8 + document.body.scrollTop + "px"
        ), 100)
      else if re = /sp\s(apps)|sp\s(extensions)/.exec(sortableTarget.className)
        mouseDownTimer = setTimeout((->
          if initSortableApps re[1] || re[2]
            mousedownEvent = document.createEvent "MouseEvent"
            mousedownEvent.initMouseEvent("mousedown", true, true, window, 0,
              event.screenX, event.screenY, event.clientX, event.clientY,
              event.ctrlKey, event.altKey, event.shiftKey, event.metaKey,
              0, null)
            event.target.dispatchEvent mousedownEvent
        ), 1)
        mouseDownTimer2 = setTimeout((->
          if mouseStateDown
            $(elDragMoving).show()
            elDragMoving.style.left = event.clientX + 15 + document.body.scrollLeft + "px"
            elDragMoving.style.top = event.clientY + 8 + document.body.scrollTop + "px"
        ), 100)
  if event.target.dataset.key is "tab"
    $(".selected").removeClass "selected"
    if event.which is 3
      $(event.target).closest(".link").addClass "selected"
  else if /title|title2/.test event.target.className
    $(".selected").removeClass "selected"
    if event.which is 3
      $(event.target).addClass "selected"
  else if /panel1|bookmarks|result|link|folder|marker/.test event.target.className
    if event.which is 1
      if (focused$ = $("a:focus")).length > 0 || $("#jqContextMenu").is(":visible")
        focused$.blur()
      else
        return # disable
    else #if event.which in [2, 3]
      unless (focused$ = $("a:focus")).length > 0
        focused$ = null
    event.preventDefault()
    event.stopPropagation()
    false

moveFocus = (list$, focused$, shiftKey) ->
  index = list$.index focused$[0]
  indexes = [list$.length - 1, [list$...].map((_, i) -> i)..., 0]
  newIndex = indexes[index + [1, -1][Number(shiftKey)] + 1]
  newTarget$ = list$.eq(newIndex)
  newTarget$.focus()

keyDownTab = (shiftKey, event) ->

  if (focused$ = $(".bookmks .title2:focus")).length > 0
    moveFocus $(".bookmks .title2:tabbable"), focused$, shiftKey
  else if (focused$ = $(".query:focus, .folders .title:focus")).length > 0
    moveFocus $(".query, .folders .title:tabbable"), focused$, shiftKey
  else if axKeyMode
    moveFocus $(".query, .folders .title:tabbable"), $(".query"), shiftKey
  else
    return

  newTarget$ = $(":focus")
  if newTarget$.hasClass("query")
    setFocusPane "query"
  else if newTarget$.hasClass("title")
    onFocusFolder currentTarget: newTarget$

clickEl = (el) ->
  virtualClick = true
  clickEvent = document.createEvent "MouseEvent"
  clickEvent.initEvent "click", true, true
  el.dispatchEvent clickEvent

setAxKeyMode = (newVal) ->
  if (axKeyMode = newVal) is 0
    $(".readyAxKey").removeClass("readyAxKey").parent().removeClass("selected").blur()
    $(".query").focus().attr("placeholder", "Search").prop("type", "text")
    $(".fa-keyboard-o").removeClass("fa-keyboard-o").addClass("fa-search")
  else # 1
    $(".ax").removeClass("readyAxKey")
    $(".result > .folder > .marker > .title > .ax").addClass("readyAxKey")
    $(".result > .link > span > .title2 > .ax").addClass("readyAxKey")
    $(".fa-search").removeClass("fa-search").addClass("fa-keyboard-o")
    $(".query").blur().attr("placeholder", "Access key").prop("type", "url")

selectAxFolder = (elAx$) ->
  $(".readyAxKey").removeClass("readyAxKey")
  elAx$.focus().parent().parent().find("> .folder > .marker > .title > .ax").addClass "readyAxKey"
  $(".bookmks .opened > .link .ax").addClass "readyAxKey"

setFocusPane = (name, shiftKey) ->
  switch name
    when "query"
      setAxKeyMode 0
      $(".query").focus()
    when "folders"
      setAxKeyMode 1
      if currentFolder = document.querySelector(".folders .folder.opened > .marker > .title")
        selectAxFolder $(currentFolder)
      else
        $(".folders .title:tabbable:first").focus()
    when "links"
      if currentFolder = document.querySelector(".folders .folder.opened > .marker > .title")
        setAxKeyMode 1
        selectAxFolder $(currentFolder)
        $(".bookmks .title2:tabbable:first").focus()
      else if shiftKey
        setFocusPane "folders"
      else
        setFocusPane "query"

onKeydownWindow = (event) ->
  switch event.key
    when "Tab"
      [, focusedClass] = /(query|title2|title)/.exec($(":focus").attr("class")) || [, null]
      switch focusedClass
        when "query"
          if event.shiftKey
            setFocusPane "links", event.shiftKey
          else
            setFocusPane "folders"
        when "title2"
          if event.shiftKey
            setFocusPane "folders"
          else
            setFocusPane "query"
        when "title"
          if event.shiftKey
            setFocusPane "query"
          else
            setFocusPane "links"
        else
          setFocusPane "folders"
    when "ArrowUp", "ArrowDown"
      keyDownTab event.key is "ArrowUp", event
      unless /title2|query/.test($(":focus").get(0)?.className)
        setAxKeyMode 1
        selectAxFolder $(":focus")
    when "ArrowLeft", "ArrowRight"
      if currentFolder = document.querySelector(".folders .folder.opened > .marker > .title")
        currentFolder.focus()
      if target = document.querySelector(".title:focus").parentElement.parentElement
        hasFolder = /hasFolder/.test target.className
        expanded = /expanded/.test target.className
        if event.key is "ArrowLeft"
          if not hasFolder or (hasFolder and not expanded) # Up to folder
            prevTarget = if isToParent = /folder/.test target.parentElement.className
              target.parentElement
            else if /opened/.test target.className
              target
            unless prevTarget
              setAxKeyMode 0
              document.querySelector(".query").focus()
              return false
            setAxKeyMode 1
            clickEl (elAx$ = $(prevTarget).find("> .marker > .title")).get(0)
            if isToParent
              selectAxFolder elAx$
            return false
          else # Coalesce folder
            expanded = false
        else #ArrowRight
          if hasFolder
            if expanded # Down to folder
              keyDownTab false, event
              setAxKeyMode 1
              selectAxFolder $(":focus")
              return false
            else # Expand folder
              expanded = true
          else if !/opened/.test target.className
            setAxKeyMode 1
            clickEl $(target).find("> .marker > .title").get(0)
        # expanded = if event.keyCode is 39 then true else false
        id = target.dataset.id
        if bmm.folderState[id]
          bmm.folderState[id].expanded = expanded
        else
          bmm.folderState[id].expanded = expanded
          bmm.folderState[id].opened = false
        setFolderState(id)
    when "Enter", "Alt"
      if (elAx$ = $(":focus:not(.query)")).length > 0 and event.key isnt "Alt"
        if elAx$.hasClass("title2")
          clickEl elAx$.get(0)
        else
          marker$ = elAx$.parent().parent()
          if marker$.hasClass("opened")
            if marker$.hasClass("hasFolder") and not marker$.hasClass("expanded")
              if options.openExclusive
                coalesceAllFolder()
              else
                closeAllFolder()
              marker$.removeClass "opened"
              clickEl elAx$.get(0)
          else
            clickEl elAx$.get(0)
          setAxKeyMode 1
          selectAxFolder elAx$
          $(".bookmks .title2:visible:first").focus()
        return false
      else if axKeyMode and event.key is "Alt"
        setAxKeyMode 0
      else if currentFolder = document.querySelector(".folders .folder.opened > .marker > .title")
        setAxKeyMode 1
        selectAxFolder $(currentFolder)
        currentFolder.focus()
        $(".bookmks .title2:visible:first").focus()
        return false
      else
        return true
    when "Escape"
      hideCtxMenu()
      $(".selected").removeClass("selected")
      if elResult$.hasClass("searched") or bmm.lastFolderState
        if axKeyMode
          setAxKeyMode 0
        else
          onClickRemoveQuery()
      else
        setAxKeyMode 0
        document.querySelector(".query").focus()
  if event.keyCode > 90 or event.keyCode < 48
    return false
  chr = String.fromCharCode(event.keyCode)
  if axKeyMode or event.altKey
    unless axKeyMode
      $(".expanded").removeClass("expanded")
      $(".opened").removeClass("opened")
      setAxKeyMode 1
    elAxs = $$(".folders .title2 > .readyAxKey, .bookmks .title2 > .readyAxKey, .folders .title > .readyAxKey")
    if event.shiftKey
      elAxs = elAxs.reverse()
    focusedIndx = -1
    foundIndxs = []
    for i in [0...elAxs.length]
      elAx = elAxs[i]
      if elAx.offsetWidth is 0
        continue
      if chr is elAx.textContent.toUpperCase()
        foundIndxs.push i
      elAx$ = $(elAx).parent()
      if elAx$.is(":focus")
        focusedIndx = i
    if foundIndxs.length is 1
      if (elAx$ = $(elAxs[foundIndxs[0]]).parent().focus()).hasClass("title")
        clickEl elAx$.get(0)
        selectAxFolder elAx$
        # setTimeout((->$(".bookmks .title2:visible:first").focus()), 50)
      else
        clickEl elAx$.get(0)
    else if foundIndxs.length > 1
      newFocusedIndx = foundIndxs[0]
      for i in [0...foundIndxs.length]
        if foundIndxs[i] > focusedIndx
          newFocusedIndx = foundIndxs[i]
          break
      setTimeout((->$(elAxs[newFocusedIndx]).parent().focus()), 50)
    event.stopPropagation()
    return false
  else
    if el = document.activeElement
      if el.tagName is "A"
        elAxs = $("a:focusable").get()
        for i in [0...elAxs.length]
          if (elLink = elAxs[i]) is el
            break
        found = false
        for j in [i+1...elAxs.length]
          elLink = elAxs[j]
          if elAx = elLink.querySelector(".ax")
            init = elAx.textContent
          else
            init = elLink.textContent.substring(0, 1)
          if chr is init.toUpperCase()
            elLink.focus()
            found = true
            break
        unless found
          for k in [0...i]
            elLink = elAxs[k]
            if elAx = elLink.querySelector(".ax")
              init = elAx.textContent
            else
              init = elLink.textContent.substring(0, 1)
            if chr is init.toUpperCase()
              elLink.focus()
              break

openSpLink = (key, value1, value2) ->
  switch key
    when "session"
      chrome.sessions.restore value1
    when "tab"
      values = value1.split(":")
      windowId = ~~values[0]
      tabId = ~~values[1]
      chrome.tabs.update tabId, { active: true }, ->
        chrome.windows.update windowId, {focused: true}, ->
          unless options.standalone
            close()
    when "app", "xts"
      if value2
        chrome.management.launchApp value1
      else
        onClickXtsSettings value1
    when "link"
      url = getUrlFromFavicon value1
      bmm.openUrl url, value2

onClickOpenLink = (event) ->
  if target = getSelected()
    if linkType = target.dataset.key
      openSpLink linkType, target.dataset.value, target.dataset.enabled
    else if (id = ($(target).parent().parent().get(0)?.dataset.id) || "1") is "none"
      imageUrl = target.style.backgroundImage
      openSpLink "link", imageUrl, event.currentTarget.className
    else
      bmm.openLink id, event.currentTarget.className
    # bmm.closeWindow()

onClickOpenModeChk = (ev) ->
  if target = getSelected()
    id = $(target).parent().parent().get(0)?.dataset.id
    openMode = (target$ = $(ev.target).parent()).get(0).className.replace(/openMode|user|default/g, "").trim()
    if folderData = bmm.getFolderData(id)
      if folderData.openMode is openMode
        openMode = null
    bmm.setFolderData id, openMode: openMode
    target$.parents("ul:first").find("li").removeClass("user default")
    if openMode
      target$.addClass "user"
  ev.stopPropagation()

onClickCloseTab = ->
  if target = getSelected()
    tabId = ~~target.dataset.value.split(":")[1]
    chrome.tabs.remove tabId

onClickMoveToNewWindow = (event) ->
  if target = getSelected()
    tabInfo = target.dataset.value.split(":")
    windowId = tabInfo[0]
    tabId = tabInfo[1]
    if /moveToSecret/.test event.target.className
      incognito = true
    else if /moveToPopup/.test event.target.className
      popup = true
    chrome.windows.update ~~windowId, {focused: true}, ->
      bmm.createNewWindow ~~tabId, incognito, popup

onClickXtsWebSite = ->
  if target = getSelected()
    appId = target.dataset.value
    chrome.management.get appId, (extInfo) ->
      chrome.tabs.query bmm.getLastWindowQuery(), (tabs) ->
        chrome.tabs.create {url: extInfo.homepageUrl, index: tabs[0].index + 1}

onClickXtsToggleEnable = ->
  if target = document.querySelector(".selected")
    unless not /disabled/.test(target.className) and target.dataset.type is "hosted_app"
      hideCtxMenu()
      xtsId = target.dataset.value
      chrome.management.get xtsId, (extInfo) ->
        chrome.management.setEnabled xtsId, !extInfo.enabled

createNewTab = (url) ->
  query = bmm.getLastWindowQuery()
  query.url = url
  delete query.active
  chrome.tabs.create query, (tab) ->
    chrome.windows.update tab.windowId, {focused: true}, (win) ->
      unless options.standalone
        close()
  # chrome.tabs.query bmm.getLastWindowQuery(), (tabs) ->
  #   chrome.tabs.create {windowId: tabs[0].windowId, url: url, index: tabs[0].index + 1}

onClickXtsOptions = ->
  if target = document.querySelector(".selected")
    if target.dataset.options is "1" and not /disabled/.test(target.className)
      hideCtxMenu()
      xtsId = target.dataset.value
      chrome.management.get xtsId, (extInfo) ->
        if extInfo.enabled and extInfo.optionsUrl
          createNewTab extInfo.optionsUrl

onClickXtsSettings = (id) ->
  if id or target = getSelected()
    xtsId = id || target.dataset.value
    chrome.tabs.query {}, (tabs) ->
      target = tabs.find (tab) ->
        /^chrome:\/\/extensions/.test tab.url
      if target
        chrome.tabs.update target.id, { url: "chrome://extensions/?id=" + xtsId, active: true }, (tab) ->
          chrome.windows.update tab.windowId, { focused: true }, ->
            unless options.standalone
              close()
      else
        createNewTab "chrome://extensions/?id=" + xtsId

onClickRestoreTab = ->
  if target = getSelected()
    sessionId = target.dataset.value
    openSpLink "session", sessionId

onClickCopyBookmark = ->
  if target = getSelected()
    copiedBmId = $(target).parent().parent().get(0)?.dataset.id
    $(".pasteBookmarks").removeClass "disabled"

onClickDeleteHistory = ->
  if target = getSelected()
    url = getUrlFromFavicon target.style.backgroundImage
    chrome.history.deleteUrl { url: url }

onClickAddGoogleBookmark = (event) ->
  if target = getSelected()
    target$ = $(target)
    chrome.tabs.query bmm.getLastWindowQuery(), ([tab]) ->
      paramList = title: tab.title, bkmk: tab.url
      unless (labels = target$.text()) is "Google Bookmarks"
        paramList.labels = labels
      params = Object.keys(paramList).map (key) ->
        key + "=" + encodeURIComponent(paramList[key])
      window.open "https://www.google.com/bookmarks/mark?op=edit&output=popup&" + params.join("&"), "googlBookmarks", "width=630,height=505"
    target$.removeClass "selected"

onClickRefreshGoogleBookmarks = (event) ->
  if target = getSelected()
    (target$ = $(target)).removeClass "selected"
    closeAllFolder()
    g_currentId = target$.parent().parent().get(0)?.dataset.id
    bmm.folderState[g_currentId].opened = true
    setFolderState()
    $(".folders .googleBookmarks .folder").remove()
    googleBookmarks$ = $(".bookmks .googleBookmarks").empty()
    if (query = $("input.query").focus().val()) is ""
      bmm.setSpecialFolders(target = googleBookmarks$.get()).done ->
        selectAxFolder($(target)) if axKeyMode
    else
      bmm.query(query, true)

onClickGotoGoogleBookmark = ->
  hideCtxMenu()
  chrome.tabs.query bmm.getLastWindowQuery(), ([tab]) ->
    chrome.tabs.create { url: "https://www.google.com/bookmarks/", index: tab.index + 1 }

onClickPasteBookmark = ->
  if copiedBmId
    target = getSelected()
    chrome.bookmarks.get copiedBmId, ([{ title, url }]) ->
      parentId = g_currentId = $(target).parent().parent().get(0)?.dataset.id || "1"
      chrome.bookmarks.create { parentId, title, urk }, (node) ->
        bmm.copyPostData copiedBmId, node.id

onClickChromeScheme = (ev) ->
  url = ev.target.textContent
  chrome.tabs.query {}, (tabs) ->
    if tabs
      found = false
      for i in [0...tabs.length]
        if url is "chrome://apps" and /^chrome:\/\/apps/.test tabs[i].url
          found = true
          options = active: true
        else if url isnt "chrome://apps" and /^chrome:\/\/settings|^chrome:\/\/history|^chrome:\/\/extensions|^chrome:\/\/help/.test tabs[i].url
          found = true
          options = active: true, url: url
        if found
          chrome.tabs.update tabs[i].id, options, (tab) ->
            chrome.windows.update tab.windowId, {focused: true}, (win) ->
              unless options.standalone
                close()
          break
      unless found
        createNewTab url

onScrollFolders = (event) ->
  bmm.onScrollFolders @

if options.standalone
  chrome.windows.onRemoved.addListener ->
    chrome.windows.getAll populate: true, (wins) ->
      if wins.length is 1
        window.close()

resizeDownX = false
resizeDownY = false
resizeDownR = false
bodyWidth = null
resultWidth = null
resultHeight = null
bodyMinWidth = 250
resultMaxWidth = 500
resultMinWidth = 125
resultMinHeight = 200
screenX = null
screenY = null

$ = jQuery
$ ->
  (dfdSubmitQueue = $.Deferred()).resolve()
  (dfdSetSpFolderQueue = $.Deferred()).resolve()

  elQuery = document.querySelector(".query")
  # elQuery.focus()
  # if options.memoryFolder
  #   unless (elQuery.value = localStorage.query || "") is ""
  #     elQuery.select()
  #     document.querySelector(".fa-times").style.display = "inherit"
  # elQuery.addEventListener "focus",
  #   (event) ->
  #     setTimeout((-> event.target.select()), 0)
  #   , false
  if ~~localStorage.axKeyMode
    bmm.dfdQueryCommit = $.Deferred()
    if elQuery.value
      bmm.dfdQueryCommit.promise()
      bmm.query elQuery.value, true
      bmm.onScrollFolders document.querySelector(".folders")
    else
      bmm.dfdQueryCommit.resolve()
    bmm.dfdQueryCommit.done ->
      if ~~localStorage.axKeyMode
        setAxKeyMode 1
        if currentFolder = document.querySelector(".folders .folder.opened > .marker > .title")
          selectAxFolder $(currentFolder)

  elResult$ = $(".result")

  $(".query")
    .on("keydown", onKeydownQuery)
    .on("keyup"  , onKeyUpQuery)
  $("form").on              "submit", onSubmitForm
  $(".addFolder").on        "click" , onClickAddFolder
  $(".delete").on           "click" , onClickDelete
  $(".editTitle").on        "click" , onClickEditTitle
  $(".editUrl").on          "click" , onClickEditUrl
  $(".copyBookmark").on     "click" , onClickCopyBookmark
  $(".pasteBookmarks").on   "click" , onClickPasteBookmark
  $(".fa-times").on         "click" , onClickRemoveQuery
  $(".closeTab").on         "click" , onClickCloseTab
  $(".xtsWebSite").on       "click" , onClickXtsWebSite
  $(".xtsToggleEnable").on  "click" , onClickXtsToggleEnable
  $(".xtsSettings").on      "click" , onClickXtsSettings
  $(".xtsOptions").on       "click" , onClickXtsOptions
  $(".restoreTab").on       "click" , onClickRestoreTab
  $(".deleteHistory").on    "click" , onClickDeleteHistory
  $(".addGoogleBookmark").on "click", onClickAddGoogleBookmark
  $(".gotoGoogleBookmark").on                          "click", onClickGotoGoogleBookmark
  $(".refreshGoogleBookmarks").on                      "click", onClickRefreshGoogleBookmarks
  $(".addBookmark,.addSelBookmarks").on                "click", onClickAddBookmark
  $(".chromeApps,.chromeExtensions,.chromeHistory").on "click", onClickChromeScheme
  $(".openMode .fa-check").on                          "click", onClickOpenModeChk
  $(".openAll,.openAllWin,.openAllSec,.openLinkCurrent,.openLinkNewTab,.openLinkNewTabRE,.openLinkNewWin,.openLinkSec,.openLinkPopup").on "click", onClickOpenLink
  $(".moveToNewWindow,.moveToSecret,.moveToPopup").on "click", onClickMoveToNewWindow
  $(".folders").on "scroll", onScrollFolders
  $(window)
    .on("unload"     , onWindowUnload)
    .on("click"      , onClickWindow)
    .on("mousewheel" , onWheelWindow)
    .on("mousedown"  , onMouseDnWindow)
    .on("keydown"    , onKeydownWindow)
    # .on("keyup"      , onKeyupWindow)
    .on("contextmenu", -> false)
  window.addEventListener "mouseup", onMouseUpWindow, true
  (bookmks$ = $(".bookmks")).niceScroll
    cursorwidth: 12
    cursorborderradius: 6
    smoothscroll: true
    cursoropacitymin: .1
    cursoropacitymax: .6
    horizrailenabled: false
    zindex: 4
    enablekeyboard: false
  bookmks$.removeAttr "tabindex"
  if options.swapPane
    resizePane = ".folders"
  else
    resizePane = ".bookmks"

	# Resizer
  document.querySelector(".resizeR").addEventListener "mousedown", (e) ->
    e.preventDefault()
    e.stopPropagation()
    resizeDownR = true
    resultWidth = $(resizePane)[0].offsetWidth
    screenX = e.screenX
  if options.standalone
    $(".resizeX,.resizeY").remove()
    resultMaxWidth = 800
  else
    document.querySelector(".resizeX").addEventListener "mousedown", (e) ->
      e.preventDefault()
      e.stopPropagation()
      resizeDownX = true
      bodyWidth = document.body.offsetWidth
      screenX = e.screenX
    document.querySelector(".resizeY").addEventListener "mousedown", (e) ->
      e.preventDefault()
      e.stopPropagation()
      resizeDownY = true
      resultHeight = document.querySelector(".folders").offsetHeight
      screenY = e.screenY
    bodyMinWidth = $(resizePane)[0].offsetWidth + resultMinWidth
    resultMaxWidth = document.body.offsetWidth - resultMinWidth
  document.addEventListener "mousemove", (e) ->
    if resizeDownX
      e.preventDefault()
      changedWidth = screenX - e.screenX
      width = bodyWidth + changedWidth
      width = Math.min(800, Math.max(bodyMinWidth, width))
      document.body.style.width = width + "px"
      localStorage.width = width
    else if resizeDownR
      e.preventDefault()
      changedWidth = screenX - e.screenX
      width = resultWidth + changedWidth
      width = Math.min(resultMaxWidth, Math.max(resultMinWidth, width))
      $(resizePane)[0].style.width = width + "px"
      localStorage.bookmksWidth = width
    else if resizeDownY
      e.preventDefault()
      changedHeight = e.screenY - screenY
      height = resultHeight + changedHeight
      height = Math.min(1000, Math.max(resultMinHeight, height))
      document.querySelector(".folders").style.height = height + "px"
      document.querySelector(".bookmks").style.height = height + "px"
      localStorage.height = height
  document.addEventListener "mouseup", (e) ->
    if resizeDownX
      e.preventDefault()
      resizeDownX = false
      resultMaxWidth = document.body.offsetWidth - resultMinWidth
    else if resizeDownY
      e.preventDefault()
      resizeDownY = false
    else if resizeDownR
      e.preventDefault()
      resizeDownR = false
      bodyMinWidth = $(resizePane)[0].offsetWidth + resultMinWidth
      resizeScrollBar()

  chrome.runtime.onMessage.addListener (req, sender, res) ->
    try
      switch req.action
        when "setColor"
          # stylesheet.addRule ".folders .result:not(.searched) .opened > .marker", "background-color:" + req.markerColor
          stylesheet.addRule ".folders .result:not(.searched) .opened > .marker > .title", "background-color:" + req.markerColorBkg
          stylesheet.addRule ".folders .result:not(.searched) .opened > .marker", "color:" + req.markerColorFont
          stylesheet.addRule ".bookmks", "border: 4px solid " + req.markerColor
        when "setZoom"
          document.body.style.zoom = req.zoom / 100
        when "doneBookmarkThing"
          reloadState()
          bmm.setSpecialFolders(target = $(".bookmks .sp.opened").get()).done ->
            selectAxFolder($(target)) if axKeyMode
        when "changeSpFolderThing"
          dfdSetSpFolderQueue = dfdSetSpFolderQueue.then ->
            if bmm.dfdQueryCommit?.state() is "pending"
              # res msg: "ok"
              return $.Deferred().resolve()
            bmm.dfdQueryCommit = $.Deferred()
            spFolders$ = $(".bookmks .sp:not(.googleBookmarks)").empty()
            if (query = $("input.query").focus().val()) is ""
              bmm.setSpecialFolders(target = spFolders$.filter(".opened").get()).done ->
                selectAxFolder($(target)) if axKeyMode
                bmm.dfdQueryCommit.resolve()
            else
              bmm.query(query, true, res)
            # res msg: "ok"
            bmm.dfdQueryCommit.promise()
        when "changeFolderIcon"
          if target = (target$ = $(".folders .folder.opened")).get(0)
            marker$ = target$.find("> .marker")
            orgClassName = (title = marker$.find(".title").get(0)).className
            title.className = orgClassName.replace(/fld\d+/, "") + " " + req.data.color
            if (iconClass = req.data.icon) is "none"
              marker$.find(".title i").remove()
            else
              if (i$ = marker$.find("i")).length > 0
                i$[0].className = iconClass
              else
                marker$.find("> .title").prepend """<i class="#{iconClass}"></i>"""
            childrenBM = []
            $.each target$.find(".folder"), (i, el) ->
              markerChild$ = $(el).find("> .marker")
              orgClassName = (titleChild$ = markerChild$.find(".title"))[0].className
              titleChild$[0].className = orgClassName.replace(/fld\d+/, "") + " " + req.data.color
              childrenBM.push el.dataset.id
            chrome.runtime.sendMessage
              action: "setFocusedFolder"
              bmId: target.dataset.id
              className: title.className
              folderName: marker$.text()
              iconName: marker$.find("i").get(0)?.className
              childrenBM: childrenBM
        when "getFocusedFolder"
          if target = (target$ = $(".folders .folder.opened")).get(0)
            marker$ = target$.find("> .marker")
            title = marker$.find(".title").get(0)
            chrome.runtime.sendMessage
              action: "setFocusedFolder"
              bmId: target?.dataset.id
              className: title.className
              folderName: marker$.text()
              iconName: marker$.find("i").get(0)?.className
              childrenBM: childrenBM
    finally
      res? msg: "ok"

  chrome.runtime.sendMessage
    action: "readyPopup"

  initCtxMenu()
  if elResult$.hasClass "searched"
    try
      $(".bookmks .folder.ui-sortable").sortable "disable"
      $(".folders .folder.ui-sortable").sortable "disable"
    catch
  if (spFolders$ = $(".bookmks .folder.sp.opened")).length > 0
    $.each spFolders$, (i, elSpFolder) ->
      id = elSpFolder.dataset.id
      if ctxMenu = bmm.spFolders.getFolderInfo(id).ctxMenu
        $(elSpFolder).find(".link a").contextMenu(ctxMenu, {})
  else if $(".bookmks .googleBookmarks .opened").length > 0
    $(".bookmks .googleBookmarks").find(".link a").contextMenu("menuBookmarkNoEdit", {})

  # ctx = document.getCSSCanvasContext("2d", "updown", 26, 24);
  # ctx.lineWidth = "2"
  # ctx.lineCap = "round"
  # ctx.lineJoin = "round"
  # ctx.strokeStyle = "#000000"
  # for i in [0..1]
  #   ctx.beginPath()
  #   ctx.moveTo 1, 5
  #   ctx.lineTo 5, 1
  #   ctx.lineTo 9, 5
  #   ctx.moveTo 5, 1
  #   ctx.lineTo 5, 9
  #   ctx.stroke()
  #   ctx.translate 18, 18
  #   ctx.rotate(180 * Math.PI / 180);
