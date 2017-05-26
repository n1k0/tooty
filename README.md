# tooty

An experimental multi-account [Mastodon Web client](https://n1k0.github.io/tooty/) written in Elm.

![](http://i.imgur.com/xxu6idX.png)

Tooty is a fully static Web application running in recent browsers, you don't need any custom server setup to use it. Just serve it and you're done, or use the [public version hosted on Github Pages](https://n1k0.github.io/tooty/).

If you want to self host Tooty, just [grab a build](https://github.com/n1k0/tooty/archive/gh-pages.zip) and serve it over HTTP.

### Setting up the development environment

    $ npm i
    $ ./node_modules/.bin/elm-package install

### Starting the dev server

    $ npm start

### Starting the dev server in live debug mode

    $ npm run debug

### Building

    $ npm run build

### Optimizing

    $ npm run optimize

This command compresses and optimizes the generated js bundle. It usually allows reducing its size by ~75%, at the cost of the JavaScript code being barely readable. Use this command for deploying tooty to production.

### Deploying to gh-pages

    $ npm run deploy

The app should be deployed to https://[your-github-username].github.io/tooty/

Note: The `deploy` command uses the `optimize` one internally.

### Launching testsuite

    $ npm test

## Licence

MIT
