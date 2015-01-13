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

Being based on Clojure promises, it might be worth having a gander at [this](https://clojuredocs.org/clojure.core/promise).

Chaingang promises derive their simplicity by wrapping Result types. Results are just like optionals but instead of having a None/nil case, they have a Failure case with an associated error value.  
Chaingang uses [LlamaKit](https://github.com/LlamaKit/LlamaKit) for Result types. So be sure to check it out for more detail on what you can do with Results.

Lets create a promise that will hold a String Result, and can fail with an NSError should things go bad.

```
let promise = Promise<String, NSError>()
```

We can realize this promise by delivering a value.

```
promise.deliver(value: "Some string.")
```

Or an error.

```
promise.deliver(error: NSError())
```

Or a result.

```
promise.deliver(success("A result."))
promise.deliver(failure(NSError()))
```

Promises are only delivered once. Subsequent deliveries are ignored. In this case, the Promise holds a successful Result containing the string "Some string.". All of the other deliveries shown are ignored. This Result will be held for the lifetime of the promise, and can be accessed by ```deref()```

```
let result = promise.deref()
```

Note that calling ```deref()``` on an unrealized Promise, will block the calling thread until another thread delivers on the Promise. We can check if a promise has been realized with ```isRealized()```.

```
promise.isRealized()    // Returns true in this case.
```

Promises can be chained using ```map``` and ```flatMap``` functional combinators.  
```
let count = promise.map { (stringResult: Result<String, NSError>) -> Result<Int, NSError> in
    return stringResult.map { transform in
        return transform.componentsSeparatedByString(" ").count
    }
}
```
In this case ```count``` is inferred to be a Promise<Int, NSError>. Since ```promise``` has been realized, the closure we passed to ```map``` is called immediatelly with the Result contained by ```promise```. The Result returned by the colusre is then delivered to ```count```, which we can then dereference.

```
let countResult = count.deref()   // Success(2)
```
So that's Chaingang in a nutshell. If you've never seen them before, ```map``` and ```flatMap``` might look a little crazy, but once you've used it a handful of times, you'll be hooked and won't be able to stop!

## Contact

It's still early days for Chaingang. And so it needs a little nurturing and TLC. Issues, Pull-requests, fan mail, and elitist hate mail are all welcome.

## Copyright & License

Chaingang Library © Copyright 2014, Matt Isaacs.

Licensed under [the MIT license](LICENSE).

