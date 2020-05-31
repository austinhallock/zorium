import * as _ from 'lodash-es'

import State from './state'
# use preactCompat for everything since the intention is to use react components
# want to make sure context gets shared properly
# (https://github.com/preactjs/preact/issues/1757)
import preactCompat from 'preact/compat'
import preactRenderToString from 'preact-render-to-string'
import parseTag from './parse_tag'

{Component, createContext, createElement, Suspense, useContext,
  useLayoutEffect, useMemo, useState} = preactCompat

DEFAULT_TIMEOUT_MS = 250

RootContext = createContext()
RootContextProvider = ({awaitStable, cache, timeout, children}) ->
  z RootContext.Provider, {value: {awaitStable, cache, timeout}}, children

z = (tagName, props, children...) ->
  isVNode = props?.__v
  if isVNode or not _.isPlainObject(props)
    if props?
      children = [props].concat children
    props = {}

  if _.isArray children[0]
    children = children[0]

  if _.isString tagName
    tagName = parseTag tagName, props

  createElement tagName, props, children

export z = z

export class Boundary extends Component
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

export classKebab = (classes) ->
  _.map _.keys(_.pickBy classes, _.identity), _.kebabCase
  .join ' '

export isSimpleClick = (e) ->
  not (e.which > 1 or e.shiftKey or e.altKey or e.metaKey or e.ctrlKey)

export useStream = (cb) ->
  {awaitStable, cache, timeout} = useContext(RootContext) or {}
  {state, hash} = useMemo ->
    initialState = cb()
    # TODO: only call cb() if not nd not awaitStable?
    {
      state: State initialState
      # this is a terrible hash and not unique at all. but i can't think of
      # anything better
      hash: (awaitStable or cache) and JSON.stringify _.keys initialState
    }
  , []

  [value, setValue] = useState state.getValue()
  [error, setError] = useState null

  if error?
    throw error

  if window?
    useLayoutEffect ->
      subscription = state.subscribe setValue, setError
      # TODO: tests for unsubscribe
      ->
        subscription.unsubscribe()
    , []
  else if awaitStable
    useMemo -> # this memo is technically pointless since it only renders once
      if awaitStable
        stableTimeout = setTimeout ->
          console.log 'timeout', hash
        , timeout
        awaitStable state._onStable().then (stableDisposable) ->
          clearTimeout stableTimeout
          setValue value = state.getValue()
          cache[hash] = value
          stableDisposable
    , [awaitStable]
  else if cache?[hash]
    value = cache[hash]

  value

# uses very hacky/not good way of caching data
# cache is based on keys from state object, so multiple components with
# {user: ...} but for different users will all yield same data...
# the correct implementation is to not have untilStable and instead have a
# renderToString that's async. react-async-ssr exists, but has a similar issue
# where state isn't kept between "renders" so it's basically the same problem.
export untilStable = (tree, {timeout} = {}) ->
  timeout ?= DEFAULT_TIMEOUT_MS
  stablePromises = []
  awaitStable = (x) -> stablePromises.push x
  cache = {}
  preactRenderToString(
    z RootContextProvider, {awaitStable, cache, timeout}, tree
  )
  try
    await Promise.race [
      Promise.all stablePromises
      .then (stableDisposables) ->
        _.map stableDisposables, (stableDisposable) ->
          stableDisposable.unsubscribe()
      new Promise (resolve, reject) ->
        setTimeout ->
          reject new Error 'Timeout'
        , timeout
    ]
  catch err
    Object.defineProperty err, 'cache',
      value: cache
      enumerable: false
    throw err
  cache

# pass in cache from untilStable to have synchronous useStream. even if
# everything is cached in exoid, it's still async because of rxjs streams
export renderToString = (tree, {cache} = {}) ->
  preactRenderToString(
    z RootContextProvider, {cache}, tree
  )

export * from 'preact/compat'
