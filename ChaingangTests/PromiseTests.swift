//
//  PromiseTests.swift
//  Chaingang
//
//  Created by Matt Isaacs.
//  Copyright (c) 2014 Matt Isaacs. All rights reserved.
//

import Chaingang
import XCTest

class promiseTestCase: XCTestCase {
    func testInit() {
        let p = Promise<Int>()
        XCTAssert(!p.isRealized(), "")
    }

    func testDelivered() {
        let p = Promise<Int>()
        p.deliver(5)
        XCTAssert(p.isRealized(), "")
        XCTAssert(p.deref().value() == 5, "")

        p.deliver(3)
        XCTAssert(p.deref().value() == 5, "")
    }

    func testWaitForDelivery() {
        let p = Promise<Int>()
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), { () -> Void in
            sleep(5)
            p.deliver(5)
        })

        XCTAssert(!p.isRealized(), "")
        XCTAssert(p.deref().value() == 5, "")
        XCTAssert(p.isRealized(), "")
    }

    func testComposition() {
        let intPromise = Promise<Int>()
        let stringPromise = intPromise.map({ (x: Int) -> String in
            return String(x)
        })
        let doubledPromise = stringPromise.map({ (s: String) -> Int in
            return s.toInt()! * 2
        })
        XCTAssert(!stringPromise.isRealized(), "")
        XCTAssert(!doubledPromise.isRealized(), "")
        intPromise.deliver(24)

        XCTAssert(doubledPromise.deref().value()? == 48, "")
    }
}

