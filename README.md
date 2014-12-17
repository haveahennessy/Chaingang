# Chaingang

Chainable Clojure style promises for Swift.
Because [Promises/A+](https://promisesaplus.com/) isn't the only way.

## Why?

[PromiseKit](https://github.com/mxcl/PromiseKit) already supplies an amazing implementation of promises for Swift and Objective-C. However, I found myself using only a tiny portion of its functionality. Furthermore, I have a personal preference for Clojure style promises over A+. Chaingang is minimalist and keeps things really simple.

## Requirements

Officially, Chaingang is intended for use with iOS 8.
Unofficially, Chaingang is really small and so can be fairly easily wrangled to work on iOS 7.

## Installation

Chaingang should be installed via [Carthage](https://github.com/Carthage/Carthage).
Add the following to your Cartfile:
```
github "haveahennessy/Chaingang"
```

And then run:
```
$ carthage update
```

Chaingang will be built as a dynamic framework, which can then be added to your application.

## Usage

Coming soon. Being based on clojure promises, it might be worth having a gander at [this](https://clojuredocs.org/clojure.core/promise).

## Contact

It's still early days for Chaingang. And so it needs a little nurturing and TLC. Issues, Pull-requests, fan mail, and elitist hate mail are all welcome.

## Copyright & License

Chaingang Library © Copyright 2014, Matt Isaacs.

Licensed under [the MIT license](LICENSE).

