//
//  util.swift
//  TouchBar
//
//  Created by Aaron Ma on 5/22/19.
//  Copyright © 2019 Firebolt, Inc. All rights reserved.
//

import Foundation
import Cocoa

@discardableResult
func with<T>(_ item: T, update: (inout T) throws -> Void) rethrows -> T {
    var this = item
    try update(&this)
    return this
}

extension CGRect {
    func adding(padding: Double) -> CGRect {
        return CGRect(
            x: origin.x - CGFloat(padding),
            y: origin.y - CGFloat(padding),
            width: width + CGFloat(padding * 2),
            height: height + CGFloat(padding * 2)
        )
    }
    
    
    func centered(in rect: CGRect, xOffset: Double = 0, yOffset: Double = 0) -> CGRect {
        return CGRect(
            x: ((rect.width - size.width) / 2) + CGFloat(xOffset),
            y: ((rect.height - size.height) / 2) + CGFloat(yOffset),
            width: size.width,
            height: size.height
        )
    }
}

extension NSWindow {
    var toolbarView: NSView? {
        return standardWindowButton(.closeButton)?.superview
    }
}

extension NSWindow {
    enum MoveXPositioning {
        case left, center, right
    }
    
    enum MoveYPositioning {
        case top, center, bottom
    }
    
    func moveTo(x xPositioning: MoveXPositioning, y yPositioning: MoveYPositioning) {
        guard let visibleFrame = NSScreen.main?.visibleFrame else {
            return
        }
        
        let x: CGFloat, y: CGFloat
        switch xPositioning {
        case .left:
            x = visibleFrame.minX
        case .center:
            x = visibleFrame.midX - frame.width / 2
        case .right:
            x = visibleFrame.maxX - frame.width
        }
        switch yPositioning {
        case .top:
            y = visibleFrame.maxY - frame.height
        case .center:
            y = visibleFrame.midY - frame.height / 2
        case .bottom:
            y = visibleFrame.minY
        }
        
        setFrameOrigin(CGPoint(x: x, y: y))
    }
}

extension NSView {
    func addSubviews(_ subviews: NSView...) {
        subviews.forEach { addSubview($0) }
    }
}

extension NSMenuItem {
    var isChecked: Bool {
        get {
            return state == .on
        }
        set {
            state = newValue ? .on : .off
        }
    }
}

extension NSMenuItem {
    convenience init(
        _ title: String,
        keyEquivalent: String = "",
        keyModifiers: NSEvent.ModifierFlags? = nil,
        isChecked: Bool = false,
        action: ((NSMenuItem) -> Void)? = nil
        ) {
        self.init(title: title, action: nil, keyEquivalent: keyEquivalent)
        
        if let keyModifiers = keyModifiers {
            self.keyEquivalentModifierMask = keyModifiers
        }
        
        self.isChecked = isChecked
        
        if let action = action {
            self.onAction = action
        }
    }
}

final class AssociatedObject<T: Any> {
    subscript(index: Any) -> T? {
        get {
            return objc_getAssociatedObject(index, Unmanaged.passUnretained(self).toOpaque()) as! T?
        } set {
            objc_setAssociatedObject(index, Unmanaged.passUnretained(self).toOpaque(), newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

@objc
protocol TargetActionSender: AnyObject {
    var target: AnyObject? { get set }
    var action: Selector? { get set }
}

extension NSControl: TargetActionSender {}
extension NSMenuItem: TargetActionSender {}
extension NSGestureRecognizer: TargetActionSender {}

private final class ActionTrampoline<Sender>: NSObject {
    typealias ActionClosure = ((Sender) -> Void)
    
    let action: ActionClosure
    
    init(action: @escaping ActionClosure) {
        self.action = action
    }
    
    @objc
    fileprivate func performAction(_ sender: TargetActionSender) {
        action(sender as! Sender)
    }
}

private struct TargetActionSenderAssociatedKeys {
    fileprivate static let trampoline = AssociatedObject<AnyObject>()
}

extension TargetActionSender {
    var onAction: ((Self) -> Void)? {
        get {
            return (TargetActionSenderAssociatedKeys.trampoline[self] as? ActionTrampoline<Self>)?.action
        }
        set {
            guard let newValue = newValue else {
                target = nil
                action = nil
                TargetActionSenderAssociatedKeys.trampoline[self] = nil
                return
            }
            
            let trampoline = ActionTrampoline(action: newValue)
            TargetActionSenderAssociatedKeys.trampoline[self] = trampoline
            target = trampoline
            action = #selector(ActionTrampoline<Self>.performAction)
        }
    }
    
    func addAction(_ action: @escaping ((Self) -> Void)) {
        let lastAction = onAction
        onAction = { sender in
            lastAction?(sender)
            action(sender)
        }
    }
}

extension NSApplication {
    var isLeftMouseDown: Bool {
        return currentEvent?.type == .leftMouseDown
    }
    
    var isOptionKeyDown: Bool {
        return NSEvent.modifierFlags.contains(.option)
    }
}

func pressKey(keyCode: CGKeyCode, flags: CGEventFlags = []) {
    let eventSource = CGEventSource(stateID: .hidSystemState)
    let keyDown = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: true)
    let keyUp = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: false)
    keyDown?.flags = flags
    keyDown?.post(tap: .cghidEventTap)
    keyUp?.post(tap: .cghidEventTap)
}

extension NSWindow.Level {
    private static func level(for cgLevelKey: CGWindowLevelKey) -> NSWindow.Level {
        return NSWindow.Level(rawValue: Int(CGWindowLevelForKey(cgLevelKey)))
    }
    
    public static let desktop = level(for: .desktopWindow)
    public static let desktopIcon = level(for: .desktopIconWindow)
    public static let backstopMenu = level(for: .backstopMenu)
    public static let dragging = level(for: .draggingWindow)
    public static let overlay = level(for: .overlayWindow)
    public static let help = level(for: .helpWindow)
    public static let utility = level(for: .utilityWindow)
    public static let assistiveTechHigh = level(for: .assistiveTechHighWindow)
    public static let cursor = level(for: .cursorWindow)
    
    public static let minimum = level(for: .minimumWindow)
    public static let maximum = level(for: .maximumWindow)
}
