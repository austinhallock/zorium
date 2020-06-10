import * as _ from 'lodash-es'

import State from './state'
// use preactCompat for everything since the intention is to use react components
// want to make sure context gets shared properly
// (https://github.com/preactjs/preact/issues/1757)
import preactCompat from 'preact/compat'
import preactRenderToString from 'preact-render-to-string'
import parseTag from './parse_tag'

const {
  Component, createContext, createElement, useContext,
  useLayoutEffect, useMemo, useState
} = preactCompat

const DEFAULT_TIMEOUT_MS = 250

export const z = function (tagName, props, ...children) {
  const isVNode = props?.__v
  if (isVNode || !_.isPlainObject(props)) {
    if (props != null) {
      children = [props].concat(children)
    }
    props = {}
  }

  if (_.isArray(children[0])) {
    children = children[0]
  }

  if (_.isString(tagName)) {
    tagName = parseTag(tagName, props)
  }

  return createElement(tagName, props, children)
}

const RootContext = createContext()
const RootContextProvider = ({ awaitStable, cache, timeout, children }) => z(RootContext.Provider, { value: { awaitStable, cache, timeout } }, children)

export class Boundary extends Component {
  constructor (props) {
    super(props)
    this.componentDidCatch = this.componentDidCatch.bind(this)
    this.render = this.render.bind(this)
    this.state = { hasError: false }
  }

  componentDidCatch (error, info) {
    return this.setState({ error, hasError: true })
  }

  render () {
    if (this.state.hasError) {
      console.log('error', this.state.error)
      this.props.fallback
    }

    return this.props.children
  }
}

export var classKebab = classes => _.map(_.keys(_.pickBy(classes, _.identity)), _.kebabCase)
  .join(' ')

export var isSimpleClick = e => !((e.which > 1) || e.shiftKey || e.altKey || e.metaKey || e.ctrlKey)

export var useStream = function (cb) {
  const { awaitStable, cache, timeout } = useContext(RootContext) || {}
  const { state, hash } = useMemo(function () {
    const initialState = cb()
    // TODO: only call cb() if not nd not awaitStable?
    return {
      state: State(initialState),
      // this is a terrible hash and not unique at all. but i can't think of
      // anything better
      hash: (awaitStable || cache) && JSON.stringify(_.keys(initialState))
    }
  }
  , [])

  let [value, setValue] = Array.from(useState(state.getValue()))
  const [error, setError] = Array.from(useState(null))

  if (error != null) {
    throw error
  }

  if (typeof window !== 'undefined' && window !== null) {
    useLayoutEffect(function () {
      const subscription = state.subscribe(setValue, setError)
      // TODO: tests for unsubscribe
      return () => subscription.unsubscribe()
    }
    , [])
  } else if (awaitStable) {
    useMemo(function () { // this memo is technically pointless since it only renders once
      if (awaitStable) {
        const stableTimeout = setTimeout(() => console.log('timeout', hash)
          , timeout)
        return awaitStable(state._onStable().then(function (stableDisposable) {
          clearTimeout(stableTimeout)
          setValue(value = state.getValue())
          cache[hash] = value
          return stableDisposable
        })
        )
      }
    }
    , [awaitStable])
  } else if (cache?.[hash]) {
    value = cache[hash]
  }

  return value
}

// uses very hacky/not good way of caching data
// cache is based on keys from state object, so multiple components with
// {user: ...} but for different users will all yield same data...
// the correct implementation is to not have untilStable and instead have a
// renderToString that's async. react-async-ssr exists, but has a similar issue
// where state isn't kept between "renders" so it's basically the same problem.
export var untilStable = async function (tree, param) {
  if (param == null) { param = {} }
  let { timeout } = param
  if (timeout == null) { timeout = DEFAULT_TIMEOUT_MS }
  const stablePromises = []
  const awaitStable = x => stablePromises.push(x)
  const cache = {}
  preactRenderToString(
    z(RootContextProvider, { awaitStable, cache, timeout }, tree)
  )
  try {
    await (Promise.race([
      Promise.all(stablePromises)
        .then(stableDisposables => _.map(stableDisposables, stableDisposable => stableDisposable.unsubscribe())),
      new Promise((resolve, reject) => setTimeout(() => reject(new Error('Timeout'))
        , timeout))
    ]))
  } catch (err) {
    Object.defineProperty(err, 'cache', {
      value: cache,
      enumerable: false
    }
    )
    throw err
  }
  return cache
}

// pass in cache from untilStable to have synchronous useStream. even if
// everything is cached in exoid, it's still async because of rxjs streams
export var renderToString = function (tree, param) {
  if (param == null) { param = {} }
  const { cache } = param
  return preactRenderToString(
    z(RootContextProvider, { cache }, tree)
  )
}

export * from 'preact/compat'
