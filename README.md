# tooty

An [experimental Mastodon client](https://n1k0.github.io/tooty/) written in Elm.

![](http://i.imgur.com/4sJCngb.png)

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

This command which will compress and optimize the generated js bundle. It usually allows reducing its size by ~75%, at the cost of the JavaScript code being barely readable. Use this command for deploying tooty to production.

### Deploying to gh-pages

    $ npm run deploy

The app should be deployed to https://[your-github-username].github.io/tooty/

Note: The `deploy` command uses the `optimize` one internally.

### Launching testsuite

    $ npm test

## Licence

MIT
