// DO NOT EDIT.
// swift-format-ignore-file
//
// Generated by the Swift generator plugin for the protocol buffer compiler.
// Source: arsdk/controller_network.proto
//
// For information on using the generated types, please see the documentation:
//   https://github.com/apple/swift-protobuf/

import Foundation
import SwiftProtobuf

// If the compiler emits an error on this type, it is because this file
// was generated by a version of the `protoc` Swift plug-in that is
// incompatible with the version of SwiftProtobuf to which you are linking.
// Please ensure that you are building against the same version of the API
// that was used to generate this file.
fileprivate struct _GeneratedWithProtocGenSwiftVersion: SwiftProtobuf.ProtobufAPIVersionCheck {
  struct _2: SwiftProtobuf.ProtobufAPIVersion_2 {}
  typealias Version = _2
}

/// This is the entry point to send messages to the drone. 
struct Arsdk_Controllernetwork_Command {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  var id: Arsdk_Controllernetwork_Command.OneOf_ID? = nil

  var getState: Arsdk_Controllernetwork_Command.GetState {
    get {
      if case .getState(let v)? = id {return v}
      return Arsdk_Controllernetwork_Command.GetState()
    }
    set {id = .getState(newValue)}
  }

  var unknownFields = SwiftProtobuf.UnknownStorage()

  enum OneOf_ID: Equatable {
    case getState(Arsdk_Controllernetwork_Command.GetState)

  #if !swift(>=4.1)
    static func ==(lhs: Arsdk_Controllernetwork_Command.OneOf_ID, rhs: Arsdk_Controllernetwork_Command.OneOf_ID) -> Bool {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch (lhs, rhs) {
      case (.getState, .getState): return {
        guard case .getState(let l) = lhs, case .getState(let r) = rhs else { preconditionFailure() }
        return l == r
      }()
      }
    }
  #endif
  }

  /// Get current state. 
  struct GetState {
    // SwiftProtobuf.Message conformance is added in an extension below. See the
    // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
    // methods supported on all messages.

    var unknownFields = SwiftProtobuf.UnknownStorage()

    init() {}
  }

  init() {}
}

/// This is the entry point to receive messages from the drone. 
struct Arsdk_Controllernetwork_Event {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  var id: Arsdk_Controllernetwork_Event.OneOf_ID? = nil

  var state: Arsdk_Controllernetwork_Event.State {
    get {
      if case .state(let v)? = id {return v}
      return Arsdk_Controllernetwork_Event.State()
    }
    set {id = .state(newValue)}
  }

  var unknownFields = SwiftProtobuf.UnknownStorage()

  enum OneOf_ID: Equatable {
    case state(Arsdk_Controllernetwork_Event.State)

  #if !swift(>=4.1)
    static func ==(lhs: Arsdk_Controllernetwork_Event.OneOf_ID, rhs: Arsdk_Controllernetwork_Event.OneOf_ID) -> Bool {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch (lhs, rhs) {
      case (.state, .state): return {
        guard case .state(let l) = lhs, case .state(let r) = rhs else { preconditionFailure() }
        return l == r
      }()
      }
    }
  #endif
  }

  /// Current state. 
  struct State {
    // SwiftProtobuf.Message conformance is added in an extension below. See the
    // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
    // methods supported on all messages.

    var linksStatus: Arsdk_Network_LinksStatus {
      get {return _linksStatus ?? Arsdk_Network_LinksStatus()}
      set {_linksStatus = newValue}
    }
    /// Returns true if `linksStatus` has been explicitly set.
    var hasLinksStatus: Bool {return self._linksStatus != nil}
    /// Clears the value of `linksStatus`. Subsequent reads from it will return its default value.
    mutating func clearLinksStatus() {self._linksStatus = nil}

    var unknownFields = SwiftProtobuf.UnknownStorage()

    init() {}

    fileprivate var _linksStatus: Arsdk_Network_LinksStatus? = nil
  }

  init() {}
}

#if swift(>=5.5) && canImport(_Concurrency)
extension Arsdk_Controllernetwork_Command: @unchecked Sendable {}
extension Arsdk_Controllernetwork_Command.OneOf_ID: @unchecked Sendable {}
extension Arsdk_Controllernetwork_Command.GetState: @unchecked Sendable {}
extension Arsdk_Controllernetwork_Event: @unchecked Sendable {}
extension Arsdk_Controllernetwork_Event.OneOf_ID: @unchecked Sendable {}
extension Arsdk_Controllernetwork_Event.State: @unchecked Sendable {}
#endif  // swift(>=5.5) && canImport(_Concurrency)

// MARK: - Code below here is support for the SwiftProtobuf runtime.

fileprivate let _protobuf_package = "arsdk.controllernetwork"

extension Arsdk_Controllernetwork_Command: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = _protobuf_package + ".Command"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    16: .standard(proto: "get_state"),
  ]

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 16: try {
        var v: Arsdk_Controllernetwork_Command.GetState?
        var hadOneofValue = false
        if let current = self.id {
          hadOneofValue = true
          if case .getState(let m) = current {v = m}
        }
        try decoder.decodeSingularMessageField(value: &v)
        if let v = v {
          if hadOneofValue {try decoder.handleConflictingOneOf()}
          self.id = .getState(v)
        }
      }()
      default: break
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    // The use of inline closures is to circumvent an issue where the compiler
    // allocates stack space for every if/case branch local when no optimizations
    // are enabled. https://github.com/apple/swift-protobuf/issues/1034 and
    // https://github.com/apple/swift-protobuf/issues/1182
    try { if case .getState(let v)? = self.id {
      try visitor.visitSingularMessageField(value: v, fieldNumber: 16)
    } }()
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: Arsdk_Controllernetwork_Command, rhs: Arsdk_Controllernetwork_Command) -> Bool {
    if lhs.id != rhs.id {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension Arsdk_Controllernetwork_Command.GetState: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = Arsdk_Controllernetwork_Command.protoMessageName + ".GetState"
  static let _protobuf_nameMap = SwiftProtobuf._NameMap()

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let _ = try decoder.nextFieldNumber() {
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: Arsdk_Controllernetwork_Command.GetState, rhs: Arsdk_Controllernetwork_Command.GetState) -> Bool {
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension Arsdk_Controllernetwork_Event: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = _protobuf_package + ".Event"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    16: .same(proto: "state"),
  ]

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 16: try {
        var v: Arsdk_Controllernetwork_Event.State?
        var hadOneofValue = false
        if let current = self.id {
          hadOneofValue = true
          if case .state(let m) = current {v = m}
        }
        try decoder.decodeSingularMessageField(value: &v)
        if let v = v {
          if hadOneofValue {try decoder.handleConflictingOneOf()}
          self.id = .state(v)
        }
      }()
      default: break
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    // The use of inline closures is to circumvent an issue where the compiler
    // allocates stack space for every if/case branch local when no optimizations
    // are enabled. https://github.com/apple/swift-protobuf/issues/1034 and
    // https://github.com/apple/swift-protobuf/issues/1182
    try { if case .state(let v)? = self.id {
      try visitor.visitSingularMessageField(value: v, fieldNumber: 16)
    } }()
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: Arsdk_Controllernetwork_Event, rhs: Arsdk_Controllernetwork_Event) -> Bool {
    if lhs.id != rhs.id {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension Arsdk_Controllernetwork_Event.State: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = Arsdk_Controllernetwork_Event.protoMessageName + ".State"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    4: .standard(proto: "links_status"),
  ]

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 4: try { try decoder.decodeSingularMessageField(value: &self._linksStatus) }()
      default: break
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    // The use of inline closures is to circumvent an issue where the compiler
    // allocates stack space for every if/case branch local when no optimizations
    // are enabled. https://github.com/apple/swift-protobuf/issues/1034 and
    // https://github.com/apple/swift-protobuf/issues/1182
    try { if let v = self._linksStatus {
      try visitor.visitSingularMessageField(value: v, fieldNumber: 4)
    } }()
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: Arsdk_Controllernetwork_Event.State, rhs: Arsdk_Controllernetwork_Event.State) -> Bool {
    if lhs._linksStatus != rhs._linksStatus {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}
