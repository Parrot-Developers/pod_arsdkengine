// DO NOT EDIT.
// swift-format-ignore-file
//
// Generated by the Swift generator plugin for the protocol buffer compiler.
// Source: arsdk/camera_alert.proto
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

enum Arsdk_Camera_Alert_Camera: SwiftProtobuf.Enum {
  typealias RawValue = Int
  case frontStereo // = 0
  case vertical // = 1
  case front // = 2
  case UNRECOGNIZED(Int)

  init() {
    self = .frontStereo
  }

  init?(rawValue: Int) {
    switch rawValue {
    case 0: self = .frontStereo
    case 1: self = .vertical
    case 2: self = .front
    default: self = .UNRECOGNIZED(rawValue)
    }
  }

  var rawValue: Int {
    switch self {
    case .frontStereo: return 0
    case .vertical: return 1
    case .front: return 2
    case .UNRECOGNIZED(let i): return i
    }
  }

}

#if swift(>=4.2)

extension Arsdk_Camera_Alert_Camera: CaseIterable {
  // The compiler won't synthesize support with the UNRECOGNIZED case.
  static var allCases: [Arsdk_Camera_Alert_Camera] = [
    .frontStereo,
    .vertical,
    .front,
  ]
}

#endif  // swift(>=4.2)

enum Arsdk_Camera_Alert_AlertState: SwiftProtobuf.Enum {
  typealias RawValue = Int
  case active // = 0
  case inactive // = 1
  case UNRECOGNIZED(Int)

  init() {
    self = .active
  }

  init?(rawValue: Int) {
    switch rawValue {
    case 0: self = .active
    case 1: self = .inactive
    default: self = .UNRECOGNIZED(rawValue)
    }
  }

  var rawValue: Int {
    switch self {
    case .active: return 0
    case .inactive: return 1
    case .UNRECOGNIZED(let i): return i
    }
  }

}

#if swift(>=4.2)

extension Arsdk_Camera_Alert_AlertState: CaseIterable {
  // The compiler won't synthesize support with the UNRECOGNIZED case.
  static var allCases: [Arsdk_Camera_Alert_AlertState] = [
    .active,
    .inactive,
  ]
}

#endif  // swift(>=4.2)

struct Arsdk_Camera_Alert_Command {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  var id: Arsdk_Camera_Alert_Command.OneOf_ID? = nil

  var getAlerts: SwiftProtobuf.Google_Protobuf_Empty {
    get {
      if case .getAlerts(let v)? = id {return v}
      return SwiftProtobuf.Google_Protobuf_Empty()
    }
    set {id = .getAlerts(newValue)}
  }

  var unknownFields = SwiftProtobuf.UnknownStorage()

  enum OneOf_ID: Equatable {
    case getAlerts(SwiftProtobuf.Google_Protobuf_Empty)

  #if !swift(>=4.1)
    static func ==(lhs: Arsdk_Camera_Alert_Command.OneOf_ID, rhs: Arsdk_Camera_Alert_Command.OneOf_ID) -> Bool {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch (lhs, rhs) {
      case (.getAlerts, .getAlerts): return {
        guard case .getAlerts(let l) = lhs, case .getAlerts(let r) = rhs else { preconditionFailure() }
        return l == r
      }()
      }
    }
  #endif
  }

  init() {}
}

struct Arsdk_Camera_Alert_Event {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  var id: Arsdk_Camera_Alert_Event.OneOf_ID? = nil

  var tooDark: Arsdk_Camera_Alert_Event.TooDark {
    get {
      if case .tooDark(let v)? = id {return v}
      return Arsdk_Camera_Alert_Event.TooDark()
    }
    set {id = .tooDark(newValue)}
  }

  var sensorFailure: Arsdk_Camera_Alert_Event.SensorFailure {
    get {
      if case .sensorFailure(let v)? = id {return v}
      return Arsdk_Camera_Alert_Event.SensorFailure()
    }
    set {id = .sensorFailure(newValue)}
  }

  var unknownFields = SwiftProtobuf.UnknownStorage()

  enum OneOf_ID: Equatable {
    case tooDark(Arsdk_Camera_Alert_Event.TooDark)
    case sensorFailure(Arsdk_Camera_Alert_Event.SensorFailure)

  #if !swift(>=4.1)
    static func ==(lhs: Arsdk_Camera_Alert_Event.OneOf_ID, rhs: Arsdk_Camera_Alert_Event.OneOf_ID) -> Bool {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch (lhs, rhs) {
      case (.tooDark, .tooDark): return {
        guard case .tooDark(let l) = lhs, case .tooDark(let r) = rhs else { preconditionFailure() }
        return l == r
      }()
      case (.sensorFailure, .sensorFailure): return {
        guard case .sensorFailure(let l) = lhs, case .sensorFailure(let r) = rhs else { preconditionFailure() }
        return l == r
      }()
      default: return false
      }
    }
  #endif
  }

  struct TooDark {
    // SwiftProtobuf.Message conformance is added in an extension below. See the
    // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
    // methods supported on all messages.

    var state: Arsdk_Camera_Alert_AlertState = .active

    var camera: Arsdk_Camera_Alert_Camera = .frontStereo

    var unknownFields = SwiftProtobuf.UnknownStorage()

    init() {}
  }

  struct SensorFailure {
    // SwiftProtobuf.Message conformance is added in an extension below. See the
    // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
    // methods supported on all messages.

    var state: Arsdk_Camera_Alert_AlertState = .active

    var camera: Arsdk_Camera_Alert_Camera = .frontStereo

    var unknownFields = SwiftProtobuf.UnknownStorage()

    init() {}
  }

  init() {}
}

#if swift(>=5.5) && canImport(_Concurrency)
extension Arsdk_Camera_Alert_Camera: @unchecked Sendable {}
extension Arsdk_Camera_Alert_AlertState: @unchecked Sendable {}
extension Arsdk_Camera_Alert_Command: @unchecked Sendable {}
extension Arsdk_Camera_Alert_Command.OneOf_ID: @unchecked Sendable {}
extension Arsdk_Camera_Alert_Event: @unchecked Sendable {}
extension Arsdk_Camera_Alert_Event.OneOf_ID: @unchecked Sendable {}
extension Arsdk_Camera_Alert_Event.TooDark: @unchecked Sendable {}
extension Arsdk_Camera_Alert_Event.SensorFailure: @unchecked Sendable {}
#endif  // swift(>=5.5) && canImport(_Concurrency)

// MARK: - Code below here is support for the SwiftProtobuf runtime.

fileprivate let _protobuf_package = "arsdk.camera.alert"

extension Arsdk_Camera_Alert_Camera: SwiftProtobuf._ProtoNameProviding {
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    0: .same(proto: "CAMERA_FRONT_STEREO"),
    1: .same(proto: "CAMERA_VERTICAL"),
    2: .same(proto: "CAMERA_FRONT"),
  ]
}

extension Arsdk_Camera_Alert_AlertState: SwiftProtobuf._ProtoNameProviding {
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    0: .same(proto: "ALERT_STATE_ACTIVE"),
    1: .same(proto: "ALERT_STATE_INACTIVE"),
  ]
}

extension Arsdk_Camera_Alert_Command: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = _protobuf_package + ".Command"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    16: .standard(proto: "get_alerts"),
  ]

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 16: try {
        var v: SwiftProtobuf.Google_Protobuf_Empty?
        var hadOneofValue = false
        if let current = self.id {
          hadOneofValue = true
          if case .getAlerts(let m) = current {v = m}
        }
        try decoder.decodeSingularMessageField(value: &v)
        if let v = v {
          if hadOneofValue {try decoder.handleConflictingOneOf()}
          self.id = .getAlerts(v)
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
    try { if case .getAlerts(let v)? = self.id {
      try visitor.visitSingularMessageField(value: v, fieldNumber: 16)
    } }()
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: Arsdk_Camera_Alert_Command, rhs: Arsdk_Camera_Alert_Command) -> Bool {
    if lhs.id != rhs.id {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension Arsdk_Camera_Alert_Event: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = _protobuf_package + ".Event"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    16: .standard(proto: "too_dark"),
    17: .standard(proto: "sensor_failure"),
  ]

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 16: try {
        var v: Arsdk_Camera_Alert_Event.TooDark?
        var hadOneofValue = false
        if let current = self.id {
          hadOneofValue = true
          if case .tooDark(let m) = current {v = m}
        }
        try decoder.decodeSingularMessageField(value: &v)
        if let v = v {
          if hadOneofValue {try decoder.handleConflictingOneOf()}
          self.id = .tooDark(v)
        }
      }()
      case 17: try {
        var v: Arsdk_Camera_Alert_Event.SensorFailure?
        var hadOneofValue = false
        if let current = self.id {
          hadOneofValue = true
          if case .sensorFailure(let m) = current {v = m}
        }
        try decoder.decodeSingularMessageField(value: &v)
        if let v = v {
          if hadOneofValue {try decoder.handleConflictingOneOf()}
          self.id = .sensorFailure(v)
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
    switch self.id {
    case .tooDark?: try {
      guard case .tooDark(let v)? = self.id else { preconditionFailure() }
      try visitor.visitSingularMessageField(value: v, fieldNumber: 16)
    }()
    case .sensorFailure?: try {
      guard case .sensorFailure(let v)? = self.id else { preconditionFailure() }
      try visitor.visitSingularMessageField(value: v, fieldNumber: 17)
    }()
    case nil: break
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: Arsdk_Camera_Alert_Event, rhs: Arsdk_Camera_Alert_Event) -> Bool {
    if lhs.id != rhs.id {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension Arsdk_Camera_Alert_Event.TooDark: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = Arsdk_Camera_Alert_Event.protoMessageName + ".TooDark"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .same(proto: "state"),
    2: .same(proto: "camera"),
  ]

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularEnumField(value: &self.state) }()
      case 2: try { try decoder.decodeSingularEnumField(value: &self.camera) }()
      default: break
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    if self.state != .active {
      try visitor.visitSingularEnumField(value: self.state, fieldNumber: 1)
    }
    if self.camera != .frontStereo {
      try visitor.visitSingularEnumField(value: self.camera, fieldNumber: 2)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: Arsdk_Camera_Alert_Event.TooDark, rhs: Arsdk_Camera_Alert_Event.TooDark) -> Bool {
    if lhs.state != rhs.state {return false}
    if lhs.camera != rhs.camera {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension Arsdk_Camera_Alert_Event.SensorFailure: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = Arsdk_Camera_Alert_Event.protoMessageName + ".SensorFailure"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .same(proto: "state"),
    2: .same(proto: "camera"),
  ]

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularEnumField(value: &self.state) }()
      case 2: try { try decoder.decodeSingularEnumField(value: &self.camera) }()
      default: break
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    if self.state != .active {
      try visitor.visitSingularEnumField(value: self.state, fieldNumber: 1)
    }
    if self.camera != .frontStereo {
      try visitor.visitSingularEnumField(value: self.camera, fieldNumber: 2)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: Arsdk_Camera_Alert_Event.SensorFailure, rhs: Arsdk_Camera_Alert_Event.SensorFailure) -> Bool {
    if lhs.state != rhs.state {return false}
    if lhs.camera != rhs.camera {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}
