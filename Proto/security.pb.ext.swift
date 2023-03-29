// Generated, do not edit !

import Foundation
import GroundSdk
import SwiftProtobuf


/// Decoder for arsdk.security.Command commands.
class ArsdkSecurityCommandEncoder {

    /// Service identifier.
    static let serviceId = "arsdk.security.Command".serviceId

    /// Gets encoder for a command.
    ///
    /// - Parameter command: command to encode
    /// - Returns: command encoder, or `nil`
    static func encoder(_ command: Arsdk_Security_Command.OneOf_ID) -> ArsdkCommandEncoder? {
        ULog.d(.tag, "ArsdkSecurityCommandEncoder command \(command)")
        var message = Arsdk_Security_Command()
        message.id = command
        if let payload = try? message.serializedData() {
            return ArsdkFeatureGeneric.customCmdEncoder(serviceId: serviceId,
                                                        msgNum: UInt(command.number),
                                                        payload: payload)
        }
        return nil
    }
}

/// Extension to get command field number.
extension Arsdk_Security_Command.OneOf_ID {
    var number: Int32 {
        switch self {
        case .registerApcToken: return 16
        case .registerApcDroneList: return 17
        }
    }
}
extension Arsdk_Security_Command.RegisterApcToken {
    static var tokenFieldNumber: Int32 { 1 }
}
extension Arsdk_Security_Command.RegisterApcDroneList {
    static var listFieldNumber: Int32 { 1 }
}
extension Arsdk_Security_Command {
    static var registerApcTokenFieldNumber: Int32 { 16 }
    static var registerApcDroneListFieldNumber: Int32 { 17 }
}
