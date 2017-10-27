//
//  InputViewController.swift
//  KMEI
//
//  Created by Gabriel Wong on 2017-09-29.
//  Copyright © 2017 SIL International. All rights reserved.
//

import AudioToolbox
import UIKit

public enum GlobeKeyTapBehaviour {
  case switchToNextKeyboard
  case switchToNextInputMethod
  case doNothing
}

public enum MenuBehaviour {
  case showAlways
  case showIfMultipleKeyboards
  case showNever
}

open class InputViewController: UIInputViewController, KeymanWebViewDelegate {
  var menuCloseButtonTitle: String?
  var isInputClickSoundEnabled = true
  var globeKeyTapBehaviour = GlobeKeyTapBehaviour.switchToNextKeyboard
  var menuBehaviour = MenuBehaviour.showAlways

  unowned var kmInputView: UIView

  open var topBarImageView: UIImageView?
  var barHeightConstraints: [NSLayoutConstraint] = []

  var containerView: UIView?
  var containerHeightConstraints: [NSLayoutConstraint] = []
  var heightConstraint: NSLayoutConstraint!
  var isTopBarEnabled: Bool

  open class var isPortrait: Bool {
    return UIScreen.main.bounds.width < UIScreen.main.bounds.height
  }

  open class var topBarHeight: Int {
    if InputViewController.isPortrait {
      return 41
    }
    return UIDevice.current.userInterfaceIdiom == .phone ? 34 : 39
  }

  open override var hasFullAccess: Bool {
    return Manager.shared.canAccessSharedContainer()
  }

  private var keyboardListCount: Int {
    let userData = Manager.shared.activeUserDefaults()
    let keyboardList = userData.installableKeyboards(forKey: Key.userKeyboardsList)
    return keyboardList?.count ?? 0
  }

  private var expandedHeight: CGFloat {
    return CGFloat(Int(kmInputView.frame.height) % 1000) +
      (isTopBarEnabled ? CGFloat(InputViewController.topBarHeight) : 0)
  }

  public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
    kmInputView = Manager.shared.inputView
    isTopBarEnabled = Manager.shared.isSystemKeyboardTopBarEnabled
    super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
  }

  public required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  open override func updateViewConstraints() {
    if view.frame.width == 0 || view.frame.height == 0 {
      super.updateViewConstraints()
      return
    }

    Manager.shared.updateViewConstraints()

    let topBarHeight = isTopBarEnabled ? CGFloat(InputViewController.topBarHeight) : 0
    barHeightConstraints[0].constant = topBarHeight

    for constraint in barHeightConstraints {
      if !view.constraints.contains(constraint) {
        view.addConstraint(constraint)
      }
    }

    containerHeightConstraints[0].constant = CGFloat(Int(kmInputView.frame.height) % 1000)
    for constraint in containerHeightConstraints {
      if !view.constraints.contains(constraint) {
        view.addConstraint(constraint)
      }
    }

    if !view.constraints.contains(heightConstraint) {
      heightConstraint.constant = expandedHeight
      view.addConstraint(heightConstraint)
    } else if heightConstraint.constant != expandedHeight {
      heightConstraint.constant = expandedHeight
    }
    super.updateViewConstraints()
  }

  open override func viewDidLoad() {
    super.viewDidLoad()

    let bgColor = UIColor(red: 210.0 / 255.0, green: 214.0 / 255.0, blue: 220.0 / 255.0, alpha: 1.0)
    view.backgroundColor = bgColor

    Manager.shared.inputViewDidLoad()
    Manager.shared.inputDelegate = self

    topBarImageView?.removeFromSuperview()
    topBarImageView = UIImageView()
    topBarImageView!.translatesAutoresizingMaskIntoConstraints = false
    topBarImageView!.backgroundColor = UIColor.gray
    view.addSubview(topBarImageView!)

    containerView?.subviews.forEach { $0.removeFromSuperview() }
    containerView?.removeFromSuperview()
    containerView = UIView()
    containerView!.translatesAutoresizingMaskIntoConstraints = false
    containerView!.backgroundColor = bgColor
    containerView!.addSubview(kmInputView)
    view.addSubview(containerView!)
  }

  open override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    setConstraints()
    inputView?.setNeedsUpdateConstraints()
  }

  open override func willRotate(to toInterfaceOrientation: UIInterfaceOrientation, duration: TimeInterval) {
    Manager.shared.inputViewWillRotate(to: toInterfaceOrientation, duration: duration)
  }

  open override func textDidChange(_ textInput: UITextInput?) {
    let contextBeforeInput = textDocumentProxy.documentContextBeforeInput ?? ""
    let contextAfterInput = textDocumentProxy.documentContextAfterInput ?? ""
    let context = "\(contextBeforeInput)\(contextAfterInput)"

    let newRange: Range<String.Index>
    if let range = context.range(of: contextBeforeInput) {
      newRange = range.upperBound..<range.upperBound
    } else {
      newRange = context.startIndex..<context.startIndex
    }

    Manager.shared.setText(context)
    Manager.shared.setSelectionRange(NSRange(newRange, in: context), manually: false)
  }

  private func processInsertText(_ fragment: String) {
    if Manager.shared.isSubKeysMenuVisible {
      return
    }

    if isInputClickSoundEnabled {
      DispatchQueue.global(qos: .default).async { AudioServicesPlaySystemSound(0x450) }

      // Disable input click sound for 0.1 second to ensure it plays for single key stroke.
      isInputClickSoundEnabled = false
      perform(#selector(self.enableInputClickSound), with: nil, afterDelay: 0.1)
    }

    let dnRange = fragment.range(of: "+dn=")!
    let sRange = fragment.range(of: "+s=")!

    let dn = Int(fragment[dnRange.upperBound..<sRange.lowerBound])!
    let s = fragment[sRange.upperBound...]

    let hexStrings: [String]
    if !s.isEmpty {
      hexStrings = s.components(separatedBy: ",")
    } else {
      hexStrings = []
    }

    let codeUnits = hexStrings.map { hexString -> UInt16 in
      let scanner = Scanner(string: hexString)
      var codeUnit: UInt32 = 0
      scanner.scanHexInt32(&codeUnit)
      return UInt16(codeUnit)
    }

    let text = String(utf16CodeUnits: codeUnits, count: codeUnits.count)

    if dn <= 0 {
      textDocumentProxy.insertText(text)
      return
    }

    for _ in 0..<dn {
      let oldContext = textDocumentProxy.documentContextBeforeInput ?? ""
      textDocumentProxy.deleteBackward()
      let newContext = textDocumentProxy.documentContextBeforeInput ?? ""
      let unitsDeleted = oldContext.utf16.count - newContext.utf16.count
      if unitsDeleted > 1 {
        if !InputViewController.isSurrogate(oldContext.utf16.last!) {
          let lowerIndex = oldContext.utf16.index(oldContext.utf16.startIndex,
                                                  offsetBy: newContext.utf16.count)
          let upperIndex = oldContext.utf16.index(lowerIndex, offsetBy: unitsDeleted - 1)
          textDocumentProxy.insertText(String(oldContext[lowerIndex..<upperIndex]))
        }
      }
    }

    if !text.isEmpty {
      textDocumentProxy.insertText(text)
    }
  }

  func updatedFragment(_ fragment: String) {
    if fragment.isEmpty {
      return
    }

    if fragment.contains("insertText") {
      processInsertText(fragment)
    } else if fragment.contains("menuKeyUp") {
      if Manager.shared.isKeyboardMenuVisible {
        return
      }

      switch globeKeyTapBehaviour {
      case .switchToNextKeyboard:
        if let nextIndex = Manager.shared.switchToNextKeyboard(), nextIndex <= 0 {
          advanceToNextInputMode()
        }
      case .switchToNextInputMethod:
        advanceToNextInputMode()
      case .doNothing:
        break
      }
    } else if fragment.contains("showKeyboardMenu") {
      switch menuBehaviour {
      case .showAlways,
           .showIfMultipleKeyboards where keyboardListCount > 1:
        Manager.shared.showKeyboardMenu(self, closeButtonTitle: menuCloseButtonTitle)
      case .showIfMultipleKeyboards, // keyboardListCount() <= 1
           .showNever:
        break
      }
    } else if fragment.contains("hideKeyboard") {
      dismissKeyboard()
    }
  }

  private func setConstraints() {
    let topBarHeight = isTopBarEnabled ? InputViewController.topBarHeight : 0
    let viewsDict = ["bar": topBarImageView!, "container": containerView!]
    barHeightConstraints = NSLayoutConstraint.constraints(
      withVisualFormat: "V:[bar(\(topBarHeight))]", metrics: nil, views: viewsDict)

    let screenWidth = UIScreen.main.bounds.width
    let barWidthConstraints = NSLayoutConstraint.constraints(
      withVisualFormat: "H:[bar(>=\(Int(screenWidth)))]", metrics: nil, views: viewsDict)
    let barVerticalPositionConstraints = NSLayoutConstraint.constraints(
      withVisualFormat: "V:|-0-[bar]", metrics: nil, views: viewsDict)
    let barHorizontalPositionConstraints = NSLayoutConstraint.constraints(
      withVisualFormat: "H:|-0-[bar]", metrics: nil, views: viewsDict)

    view.addConstraints(barHeightConstraints)
    view.addConstraints(barWidthConstraints)
    view.addConstraints(barVerticalPositionConstraints)
    view.addConstraints(barHorizontalPositionConstraints)

    // note this appears to relate to the rotation fix bug; may not work on iPads as 1000 is not enough
    containerHeightConstraints = NSLayoutConstraint.constraints(
      withVisualFormat: "V:[container(\(Int(kmInputView.frame.height) % 1000))]",
      metrics: nil, views: viewsDict)

    let containerWidthConstraints = NSLayoutConstraint.constraints(
      withVisualFormat: "H:[container(>=\(UInt(screenWidth)))]", metrics: nil, views: viewsDict)
    let containerVericalPositionConstraints = NSLayoutConstraint.constraints(
      withVisualFormat: "V:[container]-0-|", metrics: nil, views: viewsDict)
    let containerHorizontalPositionConstraints = NSLayoutConstraint.constraints(
      withVisualFormat: "H:|-0-[container]", metrics: nil, views: viewsDict)

    view.addConstraints(containerHeightConstraints)
    view.addConstraints(containerWidthConstraints)
    view.addConstraints(containerVericalPositionConstraints)
    view.addConstraints(containerHorizontalPositionConstraints)

    heightConstraint = NSLayoutConstraint(item: view,
                                          attribute: .height,
                                          relatedBy: .equal,
                                          toItem: nil,
                                          attribute: .notAnAttribute,
                                          multiplier: 0.0,
                                          constant: expandedHeight)
    heightConstraint.priority = UILayoutPriority(rawValue: 999)
  }

  @objc func enableInputClickSound() {
    isInputClickSoundEnabled = true
  }

  private class func isSurrogate(_ c: unichar) -> Bool {
    return UTF16.isLeadSurrogate(c) || UTF16.isTrailSurrogate(c)
  }
}
