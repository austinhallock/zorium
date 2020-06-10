import * as _ from 'lodash-es'
import * as Rx from 'rxjs'
import * as rx from 'rxjs/operators'

export default (function (initialState) {
  if (!_.isPlainObject(initialState)) {
    throw new Error('initialState must be a plain object')
  }

  let currentState = _.mapValues(initialState, function (val) {
    if (val?.subscribe != null) {
      // BehaviorSubject
      if (_.isFunction(val.getValue)) {
        try {
          return val.getValue()
        } catch (error) {
          return null
        }
      } else {
        return null
      }
    } else {
      return val
    }
  })
  const stateSubject = new Rx.BehaviorSubject(currentState)
  const streams = _.pickBy(initialState, x => x?.subscribe != null)

  const pendingStream = _.isEmpty(streams)
    ? Rx.of(null)
    : Rx.combineLatest(_.map(streams, (val, key) => val.pipe(rx.tap(update => currentState = _.assign(_.clone(currentState), {
      [key]: update
    })))))

  const state = Rx.combineLatest(
    [stateSubject].concat(_.map(streams, (val, key) => Rx.defer(() => Rx.of(currentState[key]))
      .pipe(
        rx.concat(
          val.pipe(rx.tap(function (update) {
            if (currentState[key] !== update) {
              return currentState = _.assign(_.clone(currentState), {
                [key]: update
              })
            }
          }))
        ),
        rx.distinctUntilChanged()
      ))
    )).pipe(rx.map(() => currentState))

  state.getValue = () => currentState
  state.set = function (diff) {
    if (!_.isPlainObject(diff)) {
      throw new Error('diff must be a plain object')
    }

    let didReplace = false
    _.map(diff, function (val, key) {
      if (initialState[key]?.subscribe != null) {
        throw new Error('Attempted to set observable value')
      } else {
        if (currentState[key] !== val) {
          return didReplace = true
        }
      }
    })

    if (didReplace) {
      currentState = _.assign(_.clone(currentState), diff)
      return stateSubject.next(currentState)
    }
  }

  let stablePromise = null
  state._onStable = function () {
    if (stablePromise != null) {
      return stablePromise
    }
    // NOTE: we subscribe here instead of take(1) to allow for state
    //  updates caused by chilren to their parents (who have already stabilized)
    let disposable = null
    return stablePromise = new Promise((resolve, reject) => disposable = pendingStream.subscribe(resolve, reject)).catch(function (err) {
      disposable?.unsubscribe()
      throw err
    }).then(() => disposable)
  }

  return state
})
