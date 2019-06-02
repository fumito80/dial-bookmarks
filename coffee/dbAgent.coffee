document.addEventListener "mousedown", (event) ->
  if event.button is 1
    chrome.runtime.sendMessage
      "action": "mousedown"
      "screenX": event.screenX
      "screenY": event.screenY
      "contextMenu": true

chrome.runtime.onMessage.addListener (req, sender, sendResponse) ->
  switch req.action
    when "hello"
      sendResponse "ok"
