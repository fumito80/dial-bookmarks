unless localStorage.height
  localStorage.height = 530
  localStorage.width = 500
  localStorage.bookmksWidth = 210
  localStorage.markerColor = "#87CEEB"
  localStorage.zoom = 100

height = localStorage.height
width = localStorage.width
bookmksWidth = localStorage.bookmksWidth

elBookmarks = document.querySelector(".bookmks")
elFolders = document.querySelector(".folders")
elBookmarks.style.width = bookmksWidth + "px"
elBookmarks.style.height = height + "px"
elFolders.style.height   = height + "px"
document.body.style.width = width + "px"
document.body.style.zoom = (localStorage.zoom || 100) / 100

# ctx = document.getCSSCanvasContext("2d", "triangle", 10, 6)
# #canvas = document.createElement("canvas")
# canvas = document.getElementById(".triangle")
# canvas.width = 10
# canvas.height = 6
# ctx = canvas.getContext('2d')
# ctx.translate(.5, .5)
# ctx.fillStyle = "#000000"
# ctx.beginPath()
# ctx.moveTo(8, 0)
# ctx.lineTo(8, .5)
# ctx.lineTo(8/2-.5, 8/2+.5)
# ctx.lineTo(0, .5)
# ctx.lineTo(0, 0)
# ctx.closePath()
# ctx.fill()
# ctx.stroke()
#
# # ctx2 = document.getCSSCanvasContext("2d", "xtsDisabled", 20, 20)
# ctx2 = document.createElement("canvas")
# CSS.elementSources.set("xtsDisabled", ctx2)
# ctx2.lineWidth = "1.1"
# ctx2.lineCap = "round"
# ctx2.lineJoin = "round"
# ctx2.strokeStyle = "#000"
# ctx2.beginPath()
# ctx2.moveTo 0, 6
# ctx2.lineTo 18, 14
# ctx2.stroke()
# # ctx.translate 18, 18

chrome.runtime.sendMessage
  action: "setBodySize"
  width: (~~width + 6) + "px"
  height: (~~height + 6) + "px"
  zoom: document.body.zoom

markerColor = localStorage.markerColor         || "#87CEEB"
markerColorBkg = localStorage.markerColorBkg   || "#FFFFFF"
markerColorFont = localStorage.markerColorFont || "#000000"
document.head.appendChild elStyle = document.createElement "style"
elStyle.setAttribute "type", "text/css"
window.stylesheet = elStyle.sheet
# stylesheet.addRule ".folders .result:not(.searched) .opened > .marker", "background-color:" + markerColor
stylesheet.addRule ".folders .result:not(.searched) .opened > .marker > .title", "background-color:" + markerColorBkg
stylesheet.addRule ".folders .result:not(.searched) .opened > .marker", "color:" + markerColorFont
stylesheet.addRule ".bookmks", "border: 4px solid " + markerColor

window.bmm = chrome.extension.getBackgroundPage().bmm

bmm.dfdQueryCommit = null

# HTML set
document.querySelector(".folders").appendChild bmm.getElResult()
document.querySelector(".bookmks").appendChild bmm.getElResult()
document.body.appendChild bmm.getHtmlCtxMenus()

document.querySelector(".query").setAttribute "placeholder", chrome.i18n.getMessage("searchBoxPalaceHolder")

window.options = bmm.getOptions()

if options.standalone
  document.body.style.width = "100%"
  elBookmarks.style.height = "100%"
  elFolders.style.height   = "100%"
  stylesheet.addRule "html", "height: 100%"

urlPopup = chrome.runtime.getURL("popup.html")

_ =
  template: (sTempl) ->
    (items) ->
      templ = sTempl
      for key of items
        templ = templ.split("<%=#{key}%>").join(items[key])
      templ

onFocusTabLink = (event) ->
  values = event.target.dataset.value.split(":")
  windowId = ~~values[0]
  tabId = ~~values[1]
  chrome.tabs.update tabId, {active: true}, ->
    # chrome.windows.update windowId, {focused: true}

gmtAdd = /GMT([+|-]\d{4})/.exec((new Date()).toString())[1] * 36000

bmm.createSpLinks = (sites, elSpFolder, className, labels) ->
  tmplLink = _.template """
    <span><a href="#" title="<%=tooltip%>" class="title2" data-key="<%=key%>" data-value="<%=value%>" style="background-image:url(<%=imageUrl%>);" tabindex="0"><i class="<%=iconClass%>"></i><%=title%></a></span>
    """
  tmplXts = _.template """
    <span class="xts"><a href="#" title="<%=tooltip%>" class="title2 <%=enabled%>" data-options="<%=optionsF%>" data-type="<%=type%>" data-key="<%=key%>" data-value="<%=value%>" style="background-image:url(<%=imageUrl%>);" tabindex="0"><i class="<%=iconClass%>"></i><%=title%></a><span class="xtsDisabled <%=enabled%>"></span></span>
    """
  spFolderInfo = bmm.spFolders.getFolderInfoByName className
  if className is "googleBookmarks" and labels.length > 0
    folderData = bmm.getFolderData()
    elSpFolder2 = document.querySelector(".folders ." + className)
    elSpFolder2.className += " hasFolder"
    parentTitleClass = elSpFolder2.querySelector(".title").className
    parentExpandMargin = ~~/(\d+)px/.exec(elSpFolder2.querySelector(".expand-icon").style.marginLeft)[1] + 15
    for i in [0...labels.length]
      bmId = "google_" + labels[i]
      folderClass = "folder virtual"
      if bmm.folderState[bmId]
        if bmm.folderState[bmId].opened
          folderClass += " opened"
      else
        bmm.folderState[bmId] = opened: false, expanded: false
      if folderInfo = folderData[bmId]
        titleClass = "title " + folderInfo.color
        iconClass = folderInfo.icon
      else
        titleClass = parentTitleClass
        iconClass = "none"
      elSpFolder.appendChild elFolder = document.createElement("div")
      elFolder.className = folderClass
      elFolder.setAttribute "data-id", bmId
      title = bmm.setAxToTitle(labels[i])
      elFolder.innerHTML = """<div class="marker"><span class="expand-icon" style="margin-left:#{parentExpandMargin}px"></span><span class="#{titleClass}" tabindex="2"><i class="#{iconClass}"></i>#{title}</span></div>"""
      elSpFolder2.appendChild elFolder2 = elFolder.cloneNode(true)
      try
        $(elFolder2).contextMenu("menuFolderGoogleLabel", {})
      catch
  for i in [0...sites.length]
    site = sites[i]
    if site.url
      if site.url.length > 128
        tooltip = site.title + "\n" + site.url.substring(0, 128) + "..."
      else
        tooltip = site.title + "\n" + site.url
      imageUrl = "chrome://favicon/" + site.url
    parentFolders = [elSpFolder]
    tmpl = tmplLink
    switch className
      when "recentHistory"
        tooltip = "LastVisit:" + (new Date(site.lastVisitTime+gmtAdd)).toISOString().substring(0, 19) + " VisitCount:" + site.visitCount + "\n" + tooltip
      when "recentlyClosed"
        key = "session"
        value = site.sessionId
      when "tabs"
        if site.url.indexOf(urlPopup) isnt -1
          continue
        key = "tab"
        value = site.windowId + ":" + site.id
        if lastWindowId and lastWindowId isnt site.windowId
          parentFolders[0].appendChild elSpan = document.createElement("span")
          elSpan.className = "windowSeparater"
          elSpan.appendChild document.createElement("hr")
        lastWindowId = site.windowId
      when "extensions", "apps"
        key = if /extensions/.test className then "xts" else "app"
        value = site.appId
        tooltip = site.tooltip
        imageUrl = site.url || "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAAQAklEQVR4nN1bW2yc13GemXP+2+5yuRdeRFISJVGy7pZk2Upip6kKJ27RNG1dJ00bFCgSFAFy6VMfgqQvKdoiQPNQ5CEI0AJBkbYpktZpkKYpEiexUweBHUW2ZcuWZF1IyySXS3G5F+71/8+Z6cOSFEmR1FISKdQDcPfnf27zzcw5Z2bOWYSbhAce/3zGiEoxYUyEEN5BhMhCLHWNtnTxJ1+aBQABANAAACdPftIpZvp2fepPP3Rk796Bwe7uriwC0H3l+B6TAHC5PFe4ciU3+RVS59Oz02Nnz/5DpAAAg0O/M/KFP//wyWNH9xzxfS+OAO8o7QMAIAD6vhcfHMxuOziy3X3m3HizOPqzWXXg8c9nP/vxDz1y7OieI/ebya2i3mx3z87+DI+Ve6fJiEqNjAxuv99MbTWNjAxuN6JSxISxVCqRvt8MbTWlUok0E8ZIhPCdtuB1QghAIoR6y0bk9pcAL1tgEUgW/7kPath8ATCAiMGL51/tnp2d9sqVsgcAQJok2Z1p9fUNNIZHHqhpIAGeF8gWCmJTBSDMWC6XnFfO/CJbq1ZdFkFh27aAEGCmntOFqXx8Zno6OP7IYwWlUTQCIG+dEDZPAAxQqZT1C//7k35jjDpyaGTg9GMnjw30ZvsBAMLIhFffmhj/9+/++GxuYpyYf07HTz06AwpYq60TwuYMwQAijK+ffykdGaN+/dGT+/74ySeeWAAPAOA62j24d+eeT3/iqQ8EvhdM5SYTc4WSG1lLRnjLHLFNk3Gr2aLC9I0gHvj+6cceehhkZY32i2ymO/XQsYPDkTFqambKt4ZRjODKxXKzaFMEIMBYLBY8YKHhHYNZ19Hu0lIAmf9sUyrZlbBGVLVSdW00bwG3CGxzaNMsgAFAxAKDLNGkLPm8SdVa3UbWEChCu4XmD7BZAhCArq6ksYJ45dr1cisMo5VaX6jXbIbmf549MyEWKJlIRcKAYhgNMC74DptJGxcAA0StJuanJvxWq05iGVf+GWZE5Uh3KhuWy/Xoq1//7vPNMIqW9SMAxXK1+Zdf+vqLlXLdxrvSYdCVMtYKikB7HZCbfVprMD85PybPC+ceCGhj2yADvHTm59mpqfEYCAAgolhBBgDP963v+RYAQBjQsqFmaBUL0BtXxiovnbs88Z5HDu1aagI/eu6lyfHcTCuVzoZBPG5HL72esrYmrlZWkeZafc6x1i7WJwBAhdLfN1B76NR7Z+Ee+AydC4ABWlGdpnLjsURX3Ns9NNBzefR6sTzXiEAETVTV1bna4vw11qI1rCJraN/uHendw9uyS8ELAMRjngYAaNSK3lRYRcelyNPakCarlRIEWTZjjh3e2zf29tRsbnKCKrVaJRYP7N06Th0LQICxOFvwhIF2Dm7r/cPfe/8TS8vn6vXaXKVWWwAn0raMHQO9vSuBL9AHP/CunQ89uDdz/uJYXim0iXhMDfZnkoAICCA9me604zrO0obf/M6Pfnz+4uVcqTDjed72BmgGB+mO94zOLUAASoWiyyw0tK03s7K4KxbEu2JBfI3tfuXjIg30ZxPb+rKJ1UrllgcAY6yKjKjQRGQjQ4ocK4pxWVC1AepMAAxggDEMW2SY0XVcbyWbGwUOAEsMfHmNNV6DAEAYWW0Nq6gFOrJCioU13bnX0PnMYQAGIBEgEUurOTS3Irgd+FtbrwZ+aa0zL18sRpFViVTKWGuQ79Jv6FgAwoKmGZKxFj3XcVfweAunqwoG2sBFVge+mkxW9hFZVsyorBVc5jPcIXU0BQQYGQDmahUHRLCnN5NaS+tr2qKsOVnW1PrySu03zEwMFo21ZOe34LuhDfkBwkKyMmW+IXNf8X6NhrfYhtx8ZxkIBFAsIyMjCrSdogWuNrgddiyA9lxbzGvhUk43W+vL3WdBZkEriIX8lD9ZrwSOQzYIXJvJ9rcy2b4QcEmq7TYC2XBCRARw5Vxfo96qpXei9aU0tK0nVigWw0uv/TLbalbQ0dpqEoukBOENSPf0No4eP1UMEjGjkeR2TtKGBKCUZkSQVisMN6r1zoDD6lpfUnf38GDXdKFYLs3OBDt39rvve9eJnYAgURiGz7947up0Pk9nX/y5ftf7Hs+DAta0vqfYsQAISeKJVIT5vORuzJZHdg8NLpRNThWqZ199s9iTSXnHD+/J+L67rN+71TrATZ/hxNG9fS/86tXc7l3DiU9//MlHXVcveooPnzj04De+/d8/eevtfOH82V9mjpw8NQuwfoqtcwEAQKa3r3Xt2pvyymtvjr/31NGDAAAvvXp58u+++q2L1jKxAA0OZP3Pfeajh4e2ZeP3SutLC04++MDA33zhk4n+3kzXynnoOo7z+x/8jXd/+Sv//MOZmUIQtqwCDwAIeC13WaX3nO7/g99+98H1wKMgMAj6Xoxv5CeDicm8uXhlPP/Ka5ennv7B82OKgFO9g3XXcUypWLavXbxaeOL0IztWolp1RehA6ysFkoj73lp9x3zfvzT6dv7G9EyUSCbDrkTSKCQhhYC4fAP7zg9euND5pkEAiCD7D58odqfTjdHrE4VXL1yd6komGrtGDhX2Hzh84+CRh/LpdKo2PVOe+9W5N3O3XeHXAC/rgF9t9V1Z9djBfdsjFjUznQ9at0mxdTwFNJBYR3M2m2k9ePI9hdKNQrVljUokM5YZwLAlayz19GarrdYclUrV+mrMrWfuS4qXv1vaogO/w1ohNkyWoZ08WRdXJ0QAYNtfr557MZWfzCXYMllmcr3A9g3tqg0MDjfCyBIhW63JKIW8Gvg1ga+BaEPg5y3qzCsXpkWY4t3pSETa7rLD6KwSMW7Ib7p2+UKikM/HuuOBc+zIvv7jRx7oC1sNNX7tQjI3fjWoVgrOXKXoKCA5tH/X4hnAfACwvrmvslAuhlpLyr//zAvjH/6zv/7Ff/zX86Orgc9PF+cuj46XXb/LpNI9rdth6jgcBgC4MZ0LQAA/9pHfemzH0LYdAAAnjx0Y/cd/+d4vr49eTjELWhZ69N1HB/t60skF8PdS6//0rWeuEyE//f2fvd1stcI/eer9+xeqTE3PVr/x7R+eJwJOdne3FJEgoqAm0WvkCzpeAwwwlkpFT8TCAngQgAN7h3d/5uNPec/+4uXLiID7du/se+TEgZGNbG2dAF8gImSt0Gil7TPPnR1/4eyF3L492xPNRsNcujZedjSZ7mSqOXLgwaLjaKsVrRsvdRwNtrOwQoZRrWR+9/Dg4O7hwcFFdtfb2lYiWny/OuKVVbVC62hlRg6cKBSmRoNGY06/celqjQgk1Z0Mk92p1t5DR2d9TxvP0ay1Eo0ka9166tgCLAsmkt3hjZmZ2GR+Znqwv6fvbhya5QA7X+EP7hsOrl2fbPqOCg+eOFUBthA1auR4ju1KdkdKOdbztQ0czziuY8khRo2yVspsQ9FgOxASFBbcqBvbbIXm3/7zp2PPv3C+MFdrRMlkTP/aI0eyH33y9G7fXcN1vnUI6OqKaUeTVVo4FniRq7Vxe9KMCkUJiXYUO1qx7ylLjmJHKdbrJE03GAwRCwA2WuHNQ44OtN5sheZv//5fz1+6Nl5RhOxq5LDZCp/52Zn62PhU+XOf/aPjvufqNblcJlxkAmBHO9Z3tQl8L/IczaSQFZIAESiFTJrEUYq1Ilnv0sWGtsF4IhmJAOami+U2V2vkBGH51vbT51/OXR6dqCSTyeb+ww9PP3jq9OSBow9PdafTtdHrueLrl8ZurKn1FZa1Z2dfFxJAM5wjx9XWdx0b+K4JYp7xY56J+Y7xPccGjmNvBx7gDvIBiCDAvK4bu7Lg/KWxoiIyA9t3lVPZdN3V2mAyJs1aiaJWXZXK1cYt/awhkSDwHQAAjgwqIUEiIYfYcZabeqdXbTq2AEKS7kxvCABw6er1mdtp/SbLAIQISpGtVwra85woFrhRvZTX5Zmc5ygye/cMpZY2uBX8zY5939PCANYaAgBQCKKRxEHNSG2BIHV+UtRRNQQSAgDf8ywCSL3RCm9hb50V/mNPPb4n1R1XtbmCMzs55ptWDXNvX4krB+2nPvHk8Z1D/RmAW819aS8LT0MDPV2AiM1qzVl4fzeJ0Y4tAAklncmGgChXxsaLi0x14MYO9GUSf/GpjxwnIm7UynqudMMhQvnd33xs7+H9u3feTuvLhhAAQBFeAftOb5RsKBwWJAn8wChCrlQb9Y1EbjuG+jNIwM1GVVfnyg4iyAN7hgc70frigwAMb+9PEyhpVCv35IJXx9Ggtu1p0J3ONGv1unf56vXJ3mw6vWOoL3uT0dUdmlYrNK+8fvVtBQjxRDLs6s6E1WrJvT4xdWNbf7Zvee2bT81WaCanCrXZYqVZLM01ZktztUp5rqoUcDKVbqFCAaK7uuWxISmiJtk2MFifyk0kvvn0j15utiK3FVkniqy2ltW+ke3JmO+7APO7BaJce2uy1Gw2m652jOsSDwwNV/3Aj6YmrsW/8/1nz1+fyFe29fVkpm8UW5P52ZDZqktXxquVuZoFQkERISIhRayVMq5WpisZb40cOFL0HM2aUJDW9vTunQAQQCPJ4NCuhjEyk5+eis/OzMZK5dmACJiNUtfeys2CtO8EIQAgASul2Pc9k+xKNQaHh8t923fUNSk+dPxU4dL5VzJnXnpjPAzNVGREG7bKWkssiJ6rUWmH/SCIPC8wgR9EQSLR6kokw76B3nosCEJHK0sO8ZZckEAgQc1CQrxzeLjW2z/UqrValbAR6lbEykRGVcolN4rCRVUoAognU2EsiEWeQ9YNXOO5jnVI8bb+oXpXMh3O5HNBuVTykVxEpYFZMIgnLWrNiCgOopBGVtphR5H1XMc6jraB7xg1v/evFereUwEAtC0AFHAEAAGAQURpkmKXLZnIUizut2TJaS0BAGnF2lGsSbHnaHa0slqjGEZMUCLyd+yxff1Rw7AlYy2JbZ9DErQXXaVQFJFoUowKpe32KnZdZR1HM2psR3qbfUME5g8YdHsgjgDAQxLtaLbWoDCgtbL8uJoASNogtCLWWgkiCGoSFwDEIIqDrB1kttJOXvLytkTtq0hIJEqRKIWsNIlGEtTY/t4qC1gUggLQRNYoRsvCLArFtDWHKyJvQRCl2wxqJEHCm16aUmBZkBxma+YPOpe0mx8SUJMQtnehhfbLgG/JJakFonk/mwEcRaIVI4gCcNpZo9UHmWd06aElAIhibN/uUGCc5dpf1nZJr/cC9HLe7pTmGVgKaLWs63q0rC2TgFre91bQ1v1i5HZ0n360Q4gsck/uXP7/IhZryCITGmpUKvXi7Zu8s2hurlUGkCYpwNKV0YmJ+83QVtOV0YkJBVhShbHnGpeKg/bg3kGnN9vdc78Z2wq68Ob1i1/+2vfOXXn2r8YVAMCezP7KM+fGm8NDWYkFLvm+F7/fTG4GFUvVwhuX3rry5a9971y6lBvN5c7apfs2PnD6i1km021RvSMFoMTWiHX5zee+WID52Pv/ABxsp/s6HjelAAAAAElFTkSuQmCC"
        settings = site.settings
        optionsF = site.optionsF
        enabled = site.enabled
        type = site.type
        tmpl = tmplXts
      when "googleBookmarks"
        if site.labels.length > 0
          parentFolders = []
          for j in [0...site.labels.length]
            parentFolders.push elSpFolder.querySelector(".folder[data-id='google_#{site.labels[j]}'")
    parentFolders.forEach (parentFolder) ->
      parentFolder.appendChild elLink = document.createElement("div")
      elLink.className = "link"
      elLink.dataset.id = "none"
      if site.title
        title = bmm.setAxToTitle(site.title)
      else
        title = tooltip
      elLink.innerHTML = tmpl
        title: title
        tooltip: tooltip
        imageUrl: imageUrl
        iconClass: spFolderInfo.iconClassName
        value: value || ""
        key: key || ""
        enabled: enabled || ""
        optionsF: optionsF || "0"
        type: type || ""
  try
    if spFolderInfo.ctxMenu
      $(elSpFolder).find(".link a").contextMenu(spFolderInfo.ctxMenu, {})
  catch
  if className is "tabs" && (options.focusLinkTab || options.hoverLinkTab)
    Array.prototype.forEach.call elSpFolder.getElementsByTagName("a"), (el) ->
      if options.focusLinkTab
        el.addEventListener "focus", onFocusTabLink, false
      if options.hoverLinkTab
        el.addEventListener "mouseover",
          (event) ->
            event.target.focus()
            document.querySelector(".query").focus()
          , false
  resizeScrollBar?()

bmm.folderState = bmm.getFolderState()

bmm.setScrollIntoView = ->
  if eltarget = document.querySelector(".folders .folder.opened")
    elScrollContainer = document.querySelector(".folders")
    elScrollContainer.scrollTop = 0
    while /folder/.test eltarget.parentElement.className
      eltarget = eltarget.parentElement
    eltarget.scrollIntoView false
    unless (scrollTop = elScrollContainer.scrollTop) is 0
      elScrollContainer.scrollTop = scrollTop + 10

bmm.onScrollFolders = (elTrget) ->
  elForm = document.querySelector(".folders > form")
  if elTrget.scrollTop < 1
    elForm.className = ""
  else
    elForm.className = "scrolling"
  elScrollEnd = document.querySelector(".folders > .scrollEnd")
  if elTrget.scrollTop >= elTrget.scrollHeight - elTrget.offsetHeight
    elScrollEnd.className = "scrollEnd"
  else
    elScrollEnd.className = "scrollEnd scrolling"

bmm.setSpecialFolders = (folders) ->
  getSpFolder = (currentClassName, className) ->
    if currentClassName.indexOf(className) isnt -1
      result = document.querySelector(".bookmks ." + className)
      if result.getElementsByClassName("link").length > 0
        false
      else
        result
    else
      false
  setSpecialFolder = (folders, dfd) ->
    if folder = folders.pop()
      if elSpFolder = getSpFolder folder.className, "googleBookmarks"
        bmm.getGoogleBookmarks().done (sites, labels) ->
          bmm.createSpLinks sites, elSpFolder, "googleBookmarks", labels
          setSpecialFolder folders, dfd
          bmm.onScrollFolders document.querySelector(".folders")
      else if elSpFolder = getSpFolder folder.className, "mostVisited"
        chrome.topSites.get (sites) ->
          bmm.createSpLinks sites, elSpFolder, "mostVisited"
          setSpecialFolder folders, dfd
      else if elSpFolder = getSpFolder folder.className, "recentHistory"
        maxResults = ~~(options.historyCount || 30)
        chrome.history.search {text: "", maxResults: maxResults}, (sites) ->
          bmm.createSpLinks sites, elSpFolder, "recentHistory"
          setSpecialFolder folders, dfd
      else if elSpFolder = getSpFolder folder.className, "recentlyClosed"
        chrome.sessions.getRecentlyClosed {maxResults: chrome.sessions.MAX_SESSION_RESULTS}, (sessions) ->
          sites = []
          sessions.forEach (session) ->
            if win = session.window
              site = {sessionId: win.sessionId, title: win.tabs.length + " Tabs", url: ""}
              tabs = []
              for i in [0...win.tabs.length]
                tabs.push win.tabs[i].title
              site.url = tabs.join ", "
            else
              site = session.tab
            sites.push site
          bmm.createSpLinks sites, elSpFolder, "recentlyClosed"
          setSpecialFolder folders, dfd
      else if elSpFolder = getSpFolder folder.className, "tabs"
        chrome.tabs.query {}, (tabs) ->
          bmm.createSpLinks tabs, elSpFolder, "tabs"
          setSpecialFolder folders, dfd
      else if elSpFolder = getSpFolder(folder.className, "apps") || getSpFolder(folder.className, "extensions")
        kind = /(apps|extensions)/.exec(folder.className)[1]
        chrome.management.getAll (extension) ->
          sites = []
          unless options.appsOrder
            options.appsOrder = {}
          extension.forEach (extension) ->
            if (kind is "apps" and /_app$/.test(extension.type)) or (kind is "extensions" and /extension/.test(extension.type))
              sites.push
                title: extension.name
                appId: extension.id
                url: extension.icons?[0].url
                tooltip: extension.description
                type: extension.type
                enabled:  if extension.enabled then "" else "disabled"
                optionsF: if extension.optionsUrl then "1" else "0"
                order: options.appsOrder[extension.id] || 9999
          sites.sort (a, b) ->
            a.order - b.order
          index = 1
          sites.forEach (site) ->
            options.appsOrder[site.appId] = index++
          bmm.createSpLinks sites, elSpFolder, kind
          setSpecialFolder folders, dfd
      else
        setSpecialFolder folders, dfd
    else
      dfd.resolve()
  setSpecialFolder folders, dfd = new MyDeferred()
  dfd.promise()

bmm.query = (query, reload) ->
  if reload
    if query is ""
      spFoldersSelector = ".bookmks .sp.opened"
      for key of bmm.folderState
        if bmm.folderState[key].opened
          if key.indexOf("google_") is 0
            spFoldersSelector = ".bookmks .googleBookmarks"
            break
    else
      spFoldersSelector = ".bookmks .sp"
    searchFolderSelector = ".bookmks .folder"
  else
    spFoldersSelector = ".bookmks .sp"
    searchFolderSelector = ".bookmks .folder"
  rootFolder = ".folders > .result > .link"
  queryU = query.toUpperCase()
  elFolders = []
  Array.prototype.forEach.call document.querySelectorAll(spFoldersSelector), (elFolder) ->
    elFolders.push elFolder
    unless query is ""
      elFolder.style.display = "none"
  bmm.setSpecialFolders(elFolders).done ->
    unless reload
      Array.prototype.forEach.call document.querySelectorAll(".link.hide"), (el) ->
        el.className = "link"
    unless query is ""
      if reload
        searchFolderSelector = ".bookmks .sp, .bookmks .sp .folder"
      else
        Array.prototype.forEach.call document.querySelectorAll(rootFolder), (el) ->
          elLink = el.getElementsByTagName("a")[0]
          if elLink.getAttribute("title").toUpperCase().indexOf(queryU) >= 0
            el.className = "link"
          else
            el.className = "link hide"
      Array.prototype.forEach.call document.querySelectorAll(searchFolderSelector), (elFolder) ->
        id = elFolder.dataset.id
        if reload
          bmm.folderState[id].hide = true
        else
          bmm.folderState[id] = {opened: false, expanded: true, hide: true}
        bmm.setFolderStateId bmm.folderState, elFolder, id
        bmm.setFolderStateId bmm.folderState, (elFoldersFolder = document.querySelector(".folders .folder[data-id='#{id}']")), id
        folderVisible = false
        Array.prototype.forEach.call elFolder.childNodes, (el) ->
          if /link/.test el.className
            elLink = el.getElementsByTagName("a")[0]
            if (elLink.getAttribute("title") + elLink.textContent).toUpperCase().indexOf(queryU) >= 0
              el.className = "link"
              folderVisible = true
            else
              el.className = "link hide"
        if folderVisible
          bmm.folderState[id].hide = false
          unless reload
            bmm.folderState[id].opened = true
          bmm.setFolderStateId bmm.folderState, elFolder, id
          bmm.setFolderStateId bmm.folderState, elFoldersFolder, id
          while /folder/.test (elFoldersFolder = elFoldersFolder.parentElement).className
            folderId = elFoldersFolder.dataset.id
            bmm.folderState[folderId].hide = false
            bmm.setFolderStateId bmm.folderState, elFoldersFolder, folderId
            bmm.setFolderStateId bmm.folderState, (elFoldersFolder = document.querySelector(".bookmks .folder[data-id='#{folderId}']")), id
      resizeScrollBar?()
    Array.prototype.forEach.call document.querySelectorAll(spFoldersSelector), (el) ->
      el.style.display = ""
    if query is ""
      bmm.setScrollIntoView()
    if bmm.dfdQueryCommit?.state() is "pending"
      bmm.dfdQueryCommit.resolve()

# Input Query setting
elQuery = document.querySelector(".query")
elQuery.focus()
if options.memoryFolder
  unless (elQuery.value = localStorage.query || "") is ""
    elQuery.select()
    document.querySelector(".fa-times").style.display = "inherit"
elQuery.addEventListener "focus",
  (event) ->
    setTimeout((-> event.target.select()), 0)
  , false
unless elQuery.value and ~~localStorage.axKeyMode
  bmm.query elQuery.value, true
  bmm.onScrollFolders document.querySelector(".folders")

setTimeout((->
  document.body.appendChild elScript = document.createElement("script")
  elScript.setAttribute "src", "popup2.js"
), 0)

if options.swapPane
  document.querySelector(".bookmarks").appendChild elBookmks = document.querySelector(".bookmks")
  elBookmks.style.width = "auto"
  elBookmks.style.float = "none"
  (elFolders = document.querySelector(".folders")).style.float = "right"
  elFolders.style.width = bookmksWidth + "px"
  elFolders.appendChild document.querySelector(".resizeR")
