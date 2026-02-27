// AndroidCompatStubs.swift
// Compile-time shims for Skip's Android bridge compilation (-DSKIP_BRIDGE).
// The Swift compiler passes -DTARGET_OS_ANDROID for android builds.
// These stubs make the code compile; Skip's Kotlin runtime provides real behavior.

#if TARGET_OS_ANDROID && !SKIP
import SwiftUI

// MARK: - ObservableObject + Published (Combine replacements)

public protocol ObservableObject: AnyObject {}

@propertyWrapper
public struct Published<Value> {
    public var wrappedValue: Value
    public init(wrappedValue: Value) { self.wrappedValue = wrappedValue }
    public init(initialValue: Value) { self.wrappedValue = initialValue }
}

// MARK: - StateObject

@frozen @propertyWrapper
public struct StateObject<ObjectType: AnyObject> {
    public var wrappedValue: ObjectType

    public init(wrappedValue: @autoclosure () -> ObjectType) {
        self.wrappedValue = wrappedValue()
    }

    @dynamicMemberLookup
    public struct Wrapper {
        var root: ObjectType
        public subscript<T>(dynamicMember keyPath: ReferenceWritableKeyPath<ObjectType, T>) -> Binding<T> {
            Binding(
                get: { self.root[keyPath: keyPath] },
                set: { self.root[keyPath: keyPath] = $0 }
            )
        }
    }

    public var projectedValue: Wrapper { Wrapper(root: wrappedValue) }
}

// MARK: - ObservedObject

@frozen @propertyWrapper
public struct ObservedObject<ObjectType: AnyObject> {
    public var wrappedValue: ObjectType

    public init(wrappedValue: ObjectType) { self.wrappedValue = wrappedValue }
    public init(initialValue: ObjectType) { self.wrappedValue = initialValue }

    @dynamicMemberLookup
    public struct Wrapper {
        var root: ObjectType
        public subscript<T>(dynamicMember keyPath: ReferenceWritableKeyPath<ObjectType, T>) -> Binding<T> {
            Binding(
                get: { self.root[keyPath: keyPath] },
                set: { self.root[keyPath: keyPath] = $0 }
            )
        }
    }

    public var projectedValue: Wrapper { Wrapper(root: wrappedValue) }
}

// MARK: - SceneStorage

@propertyWrapper
public struct SceneStorage<Value> {
    public var wrappedValue: Value

    public init(wrappedValue: Value, _ key: String) {
        self.wrappedValue = wrappedValue
    }

    public var projectedValue: Binding<Value> {
        .constant(wrappedValue)
    }
}

// MARK: - UIColor semantic color stubs
// Provides Color(.systemBackground) etc. for Android bridge compilation.
// Color.init(_ resolved: Color.Resolved) matches Color(.systemBackground) syntax.

extension Color.Resolved {
    public static var systemBackground: Color.Resolved {
        Color.Resolved(red: 1.0, green: 1.0, blue: 1.0, opacity: 1)
    }
    public static var secondarySystemBackground: Color.Resolved {
        Color.Resolved(red: 0.95, green: 0.95, blue: 0.97, opacity: 1)
    }
    public static var tertiarySystemBackground: Color.Resolved {
        Color.Resolved(red: 0.95, green: 0.95, blue: 0.97, opacity: 1)
    }
    public static var systemGroupedBackground: Color.Resolved {
        Color.Resolved(red: 0.95, green: 0.95, blue: 0.97, opacity: 1)
    }
    public static var secondarySystemGroupedBackground: Color.Resolved {
        Color.Resolved(red: 1.0, green: 1.0, blue: 1.0, opacity: 1)
    }
    public static var tertiarySystemGroupedBackground: Color.Resolved {
        Color.Resolved(red: 0.95, green: 0.95, blue: 0.97, opacity: 1)
    }
    public static var systemGray6: Color.Resolved {
        Color.Resolved(red: 0.95, green: 0.95, blue: 0.97, opacity: 1)
    }
    public static var systemGray5: Color.Resolved {
        Color.Resolved(red: 0.90, green: 0.90, blue: 0.92, opacity: 1)
    }
    public static var systemGray4: Color.Resolved {
        Color.Resolved(red: 0.82, green: 0.82, blue: 0.84, opacity: 1)
    }
    public static var systemGray3: Color.Resolved {
        Color.Resolved(red: 0.71, green: 0.71, blue: 0.73, opacity: 1)
    }
    public static var systemGray2: Color.Resolved {
        Color.Resolved(red: 0.68, green: 0.68, blue: 0.70, opacity: 1)
    }
    public static var systemGray: Color.Resolved {
        Color.Resolved(red: 0.56, green: 0.56, blue: 0.58, opacity: 1)
    }
}

#endif
