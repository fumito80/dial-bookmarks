document.addEventListener "mousedown", (event) ->
  if event.button is 2
    chrome.runtime.sendMessage
      "action": "mousedown"
      "screenX": event.screenX
      "screenY": event.screenY
      "contextMenu": true
    false

document.addEventListener "contextmenu", (event) ->
  event.preventDefault()
  false
, false

chrome.runtime.onMessage.addListener (req, sender, sendResponse) ->
  switch req.action
    when "hello"
      sendResponse "ok"
