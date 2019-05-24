chrome.runtime.onMessage.addListener (req, sender, sendResponse) ->
  switch req.action
    when "hello"
      sendResponse "ok"
    when "sendPostData"
      document.body.appendChild myform = document.createElement "form"
      myform.style.displey = "hidden"
      myform.setAttribute "method", "POST"
      myform.setAttribute "action", req.url
      for key of req.data
        for i in [0...req.data[key].length]
          myform.appendChild elInput = document.createElement "input"
          elInput.setAttribute "type", "hidden"
          elInput.setAttribute "name", key
          elInput.setAttribute "value", req.data[key][i]
      if req.openMode is "openLinkCurrent"
        myform.removeAttribute "target"
      else
        window.open "about:blank", windowName = "w" + (new Date).getTime()
        myform.setAttribute "target", windowName
      myform.submit()
      document.body.removeChild myform

return "ok"
