_isPlainObject = require 'lodash/isPlainObject'
_isArray = require 'lodash/isArray'
_isString = require 'lodash/isString'
_defaults = require 'lodash/defaults'
_map = require 'lodash/map'
_keys = require 'lodash/keys'
_pickBy = require 'lodash/pickBy'
_identity = require 'lodash/identity'
_kebabCase = require 'lodash/kebabCase'

State = require './state'
# missing Context (useContext)
# use preactCompat for everything since the intention is to use react components
# want to make sure context gets shared properly
# (https://github.com/preactjs/preact/issues/1757)
preactCompat = require 'preact/compat'
renderToString = require 'preact-render-to-string'
parseTag = require './parse_tag'

{render, createElement, Component, Suspense, useMemo, useContext,
  useState, useLayoutEffect} = preactCompat
h = createElement

DEFAULT_TIMEOUT_MS = 250

z = (tagName, props, children...) ->
  isVNode = props?.__v
  if isVNode or not _isPlainObject(props)
    if props?
      children = [props].concat children
    props = {}

  if _isArray children[0]
    children = children[0]

  if _isString tagName
    tagName = parseTag tagName, props

  h tagName, props, children

# RootContext = ({shouldSuspend, awaitStable, children}) ->
#   z Context, {value: {shouldSuspend, awaitStable}}, children

module.exports = _defaults {
  z

  Boundary: class Boundary extends Component
    constructor: (props) ->
      super props
      @state = hasError: false

    componentDidCatch: (error, info) =>
      @setState {error, hasError: true}

    render: =>
      if @state.hasError
        console.log 'error', @state.error
        @props.fallback

      @props.children

  # Boundary: ({children, fallback}) ->
  #   z dyo.Boundary,
  #     fallback: (err) ->
  #       fallback err.message
  #     children

  classKebab: (classes) ->
    _map _keys(_pickBy classes, _identity), _kebabCase
    .join ' '

  isSimpleClick: (e) ->
    not (e.which > 1 or e.shiftKey or e.altKey or e.metaKey or e.ctrlKey)

  useStream: (cb) ->
    {awaitStable, shouldSuspend} = {} # useContext RootContext
    state = useMemo ->
      # TODO: only call cb() if not shouldSuspend and not awaitStable?
      State(cb())
    , []

    [value, setValue] = useState state.getValue()
    [error, setError] = useState null

    if error?
      throw error

    if shouldSuspend
      # XXX
      value = useResource ->
        state._onStable().then (stableDisposable) ->
          # TODO: is this a huge performance penalty? (for concurrent)
          # FIXME: should promise chain the nextTick (+tests)
          process.nextTick ->
            stableDisposable.unsubscribe()
        .then -> state.getValue()
    else if window?
      useLayoutEffect ->
        subscription = state.subscribe setValue, setError
        # TODO: tests for unsubscribe
        ->
          subscription.unsubscribe()
      , []
    else
      useMemo ->
        if awaitStable?
          awaitStable state._onStable().then (stableDisposable) ->
            setValue value = state.getValue()
            stableDisposable
      , [awaitStable]

    value

  # render: (tree, $$root) ->
  #   render z(RootContext, {shouldSuspend: false}, tree), $$root

  renderToString: (tree, {timeout} = {}) ->
    renderToString tree

    # timeout ?= DEFAULT_TIMEOUT_MS
    #
    # stablePromises = []
    # awaitStable = (x) -> stablePromises.push x
    # initialHtml = await render \
    #   z(RootContext, {shouldSuspend: false, awaitStable}, tree), {}
    #
    # try
    #   return await Promise.race [
    #     Promise.all stablePromises
    #     .then (stableDisposables) ->
    #       render \
    #         z(RootContext, {shouldSuspend: true}, z Suspense, tree), {}
    #       .then (html) ->
    #         _map stableDisposables, (stableDisposable) ->
    #           stableDisposable.unsubscribe()
    #         html
    #     new Promise (resolve, reject) ->
    #       setTimeout ->
    #         reject new Error 'Timeout'
    #       , timeout
    #   ]
    # catch err
    #   Object.defineProperty err, 'html',
    #     value: initialHtml
    #     enumerable: false
    #   throw err
}, preactCompat
