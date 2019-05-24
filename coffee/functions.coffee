F =
  $$: (selector, parent = document) -> [parent.querySelectorAll(selector)...]
  range: (from, to) -> [Array(to - from + 1)...].map((_, i) => i + from)
  pipe: (fn, fns...) -> (a) -> fns.reduce ((acc, fn2) -> fn2(acc)), fn(a)
  map: (f) -> (a) -> a.map f
  filter: (f) -> (a) -> a.filter f
  find: (f) -> (a) -> a.find f
  findIndex: (f) -> (a) -> a.findIndex f

class MyDeferred
  _state: "pending"
  fn: null
  state: -> @_state
  promise: -> @
  done: (fn) ->
    if @state() is "resolved"
      fn()
    else
      @fn = fn
  resolve: ->
    if @fn
      @fn()
    else
      @_state = "resolved"
  @when: (loaders) ->
    doneCount = 0
    done: (fn) ->
      loaders.forEach (loader) ->
        loader.done ->
          if ++doneCount is loaders.length
            fn()
