[![Zorium](./icons/zorium_logo.png)](https://zorium.org/)

## [Zorium](https://zorium.org/) - The CoffeeScript Web Framework

#### [zorium.org](https://zorium.org/)

(╯°□°)╯︵ ┻━┻
v2.0.0

### Features

  - First Class [RxJS Observables](https://github.com/Reactive-Extensions/RxJS)
  - Built for Isomorphism (server-side rendering)
  - Standardized [Best Practices](https://zorium.org/best-practices)
  - [Material Design Components](https://zorium.org/paper)
  - Production-ready [Seed Project](https://github.com/Zorium/zorium-seed)
  - It's just CoffeeScript, no magic

### Example

```coffee
z = require 'zorium'

class Icon
  render: ({children}) ->
    z '.icon', children

class AppComponent
  constructor: ->
    @state = z.state
      name: 'Zorium'

  render: =>
    {name} = @state.getValue()

    z '.zorium',
      z 'p.text',
        z Icon, 'fireworks'
        "The Future -#{name}"

z.render new AppComponent(), document.body
```

### Documentation

[zorium.org](https://zorium.org/)

### Installation

```bash
yarn add zorium
```

### Contribute

```bash
yarn install
yarn test
```

### Changelog
  - 1.x -> 2
    - [breaking] deprecate `z.ev()`
    - [breaking] deprecate `attributes` property for manually specifying attributes
    - [breaking] deprecate `z.router`
    - [breaking] upgrade to RxJS v5
    - [breaking] remove requestAnimationFrame and Promise polyfill
    - add support for rendering static classes as components
    - migrate backend from [virtual-dom](https://github.com/Matt-Esch/virtual-dom) to [dio.js](https://github.com/thysultan/dio.js)
