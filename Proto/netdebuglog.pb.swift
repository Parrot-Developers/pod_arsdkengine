// DO NOT EDIT.
// swift-format-ignore-file
//
// Generated by the Swift generator plugin for the protocol buffer compiler.
// Source: arsdk/netdebuglog.proto
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

/// This is the entry point to receive messages from the drone. 
struct Arsdk_Netdebuglog_Event {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  var id: Arsdk_Netdebuglog_Event.OneOf_ID? = nil

  var log: Arsdk_Netdebuglog_Event.Log {
    get {
      if case .log(let v)? = id {return v}
      return Arsdk_Netdebuglog_Event.Log()
    }
    set {id = .log(newValue)}
  }

  var unknownFields = SwiftProtobuf.UnknownStorage()

  enum OneOf_ID: Equatable {
    case log(Arsdk_Netdebuglog_Event.Log)

  #if !swift(>=4.1)
    static func ==(lhs: Arsdk_Netdebuglog_Event.OneOf_ID, rhs: Arsdk_Netdebuglog_Event.OneOf_ID) -> Bool {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch (lhs, rhs) {
      case (.log, .log): return {
        guard case .log(let l) = lhs, case .log(let r) = rhs else { preconditionFailure() }
        return l == r
      }()
      }
    }
  #endif
  }

  /// Log message. 
  struct Log {
    // SwiftProtobuf.Message conformance is added in an extension below. See the
    // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
    // methods supported on all messages.

    /// Serial number of sender. 
    var serial: String = String()

    /// Log message. 
    var msg: String = String()

    var unknownFields = SwiftProtobuf.UnknownStorage()

    init() {}
  }

  init() {}
}

#if swift(>=5.5) && canImport(_Concurrency)
extension Arsdk_Netdebuglog_Event: @unchecked Sendable {}
extension Arsdk_Netdebuglog_Event.OneOf_ID: @unchecked Sendable {}
extension Arsdk_Netdebuglog_Event.Log: @unchecked Sendable {}
#endif  // swift(>=5.5) && canImport(_Concurrency)

// MARK: - Code below here is support for the SwiftProtobuf runtime.

fileprivate let _protobuf_package = "arsdk.netdebuglog"

extension Arsdk_Netdebuglog_Event: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = _protobuf_package + ".Event"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    17: .same(proto: "log"),
  ]

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 17: try {
        var v: Arsdk_Netdebuglog_Event.Log?
        var hadOneofValue = false
        if let current = self.id {
          hadOneofValue = true
          if case .log(let m) = current {v = m}
        }
        try decoder.decodeSingularMessageField(value: &v)
        if let v = v {
          if hadOneofValue {try decoder.handleConflictingOneOf()}
          self.id = .log(v)
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
    try { if case .log(let v)? = self.id {
      try visitor.visitSingularMessageField(value: v, fieldNumber: 17)
    } }()
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: Arsdk_Netdebuglog_Event, rhs: Arsdk_Netdebuglog_Event) -> Bool {
    if lhs.id != rhs.id {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension Arsdk_Netdebuglog_Event.Log: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = Arsdk_Netdebuglog_Event.protoMessageName + ".Log"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .same(proto: "serial"),
    2: .same(proto: "msg"),
  ]

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularStringField(value: &self.serial) }()
      case 2: try { try decoder.decodeSingularStringField(value: &self.msg) }()
      default: break
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    if !self.serial.isEmpty {
      try visitor.visitSingularStringField(value: self.serial, fieldNumber: 1)
    }
    if !self.msg.isEmpty {
      try visitor.visitSingularStringField(value: self.msg, fieldNumber: 2)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: Arsdk_Netdebuglog_Event.Log, rhs: Arsdk_Netdebuglog_Event.Log) -> Bool {
    if lhs.serial != rhs.serial {return false}
    if lhs.msg != rhs.msg {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}
