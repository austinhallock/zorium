_isPlainObject = require 'lodash/isPlainObject'
_mapValues = require 'lodash/mapValues'
_pickBy = require 'lodash/pickBy'
_isEmpty = require 'lodash/isEmpty'
_isFunction = require 'lodash/isFunction'
_map = require 'lodash/map'
_clone = require 'lodash/clone'
_assign = require 'lodash/assign'
RxBehaviorSubject = require('rxjs/BehaviorSubject').BehaviorSubject
RxObservable = require('rxjs/Observable').Observable
require 'rxjs/add/observable/combineLatest'
require 'rxjs/add/observable/defer'
require 'rxjs/add/observable/of'
require 'rxjs/add/operator/concat'
require 'rxjs/add/operator/do'
require 'rxjs/add/operator/map'
require 'rxjs/add/operator/distinctUntilChanged'

module.exports = (initialState) ->
  unless _isPlainObject(initialState)
    throw new Error 'initialState must be a plain object'

  currentState = _mapValues initialState, (val) ->
    if val?.subscribe?
      # BehaviorSubject
      if _isFunction val.getValue
        try
          val.getValue()
        catch
          null
      else
        null
    else
      val
  stateSubject = new RxBehaviorSubject currentState
  streams = _pickBy initialState, (x) -> x?.subscribe?

  pendingStream = if _isEmpty streams
    RxObservable.of null
  else
    RxObservable.combineLatest _map streams, (val, key) ->
      val.do (update) ->
        currentState = _assign _clone(currentState), {
          "#{key}": update
        }

  state = RxObservable.combineLatest \
  [stateSubject].concat _map streams, (val, key) ->
    RxObservable.defer ->
      RxObservable.of currentState[key]
    .concat(
      val.do (update) ->
        if currentState[key] isnt update
          currentState = _assign _clone(currentState), {
            "#{key}": update
          }
    )
    .distinctUntilChanged()
  .map -> currentState

  state.getValue = -> currentState
  state.set = (diff) ->
    unless _isPlainObject(diff)
      throw new Error 'diff must be a plain object'

    didReplace = false
    _map diff, (val, key) ->
      if initialState[key]?.subscribe?
        throw new Error 'Attempted to set observable value'
      else
        if currentState[key] isnt val
          didReplace = true

    if didReplace
      currentState = _assign _clone(currentState), diff
      stateSubject.next currentState

  stablePromise = null
  state._onStable = ->
    if stablePromise?
      return stablePromise
    # NOTE: we subscribe here instead of take(1) to allow for state
    #  updates caused by chilren to their parents (who have already stabilized)
    disposable = null
    stablePromise = new Promise (resolve, reject) ->
      disposable = pendingStream.subscribe resolve, reject
    .catch (err) ->
      disposable?.unsubscribe()
      throw err
    .then -> disposable

  return state
