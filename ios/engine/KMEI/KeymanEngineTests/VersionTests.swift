//
//  VersionTests.swift
//  KeymanEngineTests
//
//  Created by Joshua Horton on 2020-02-13.
//  Copyright © 2020 SIL International. All rights reserved.
//

@testable import KeymanEngine
import XCTest

class VersionTests: XCTestCase {

  override func setUp() {
    // Put setup code here. This method is called before the invocation of each test method in the class.
  }

  override func tearDown() {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
  }

  func testStringConstruction() {
    let simpleEarly = Version("11.0")

    XCTAssertNotNil(simpleEarly, "Could not construct Version instance from a simple major-minor version string")

    let complexEarly = Version("11.0.65.17.8")

    XCTAssertNotNil(complexEarly, "Could not process the version string '11.0.65.17.8'")

    let broken = Version("apple.orange")

    XCTAssertNil(broken, "Erroneously constructed Version instance from character-text strings")

    let tagged = Version("14.0.18-alpha-local")

    XCTAssertNotNil(tagged, "Could not construct Verison instance from a text-tagged version string")
    XCTAssertEqual(tagged, Version("14.0.18"), "Did not produce expected version from text-tagged version string")
  }

  func testVersionComparison() {
    // Simple unit testing for version-comparison logic.
    let simpleEarly = Version("11.0")!
    let simpleLate = Version("13.0")!

    XCTAssertLessThan(simpleEarly, simpleLate)

    let complexEarly1 = Version("11.0.65")!
    let complexEarly2 = Version("11.1.1")!

    XCTAssertLessThan(complexEarly1, complexEarly2)

    let complexLate1 = Version("13.0.1")!

    XCTAssertLessThan(complexEarly2, complexLate1)
    XCTAssertLessThan(simpleLate, complexLate1)

    let simpleLater = Version("13.1")!

    XCTAssertLessThan(complexLate1, simpleLater)
  }

  func testMajorMinor() {
    let simple = Version("12")!

    XCTAssertEqual(simple.majorMinor, Version("12.0")!, "Did not append .minor to major-only version")

    let complex = Version("11.0.65.17.8")!

    XCTAssertEqual(complex.majorMinor, Version("11.0")!, "Did not properly trim off excess version components")
  }

  func testValidCurrentEngineVersion() {
    let version = Version.current

    // Do not test on value; this may mismatch with the actual version, since the test host doesn't get
    // version number updates from builds.
    //
    // The key is that it always returns a version value; this is the most likely 'big break' we may see.
    XCTAssertNotNil(version, "Could not construct a valid version from value in bundle's plist file")
  }
}
