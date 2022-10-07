#!/usr/bin/env python3
'''
	Copyright (C) 2020 Parrot Drones SAS

	Redistribution and use in source and binary forms, with or without
	modification, are permitted provided that the following conditions
	are met:
	* Redistributions of source code must retain the above copyright
	  notice, this list of conditions and the following disclaimer.
	* Redistributions in binary form must reproduce the above copyright
	  notice, this list of conditions and the following disclaimer in
	  the documentation and/or other materials provided with the
	  distribution.
	* Neither the name of the Parrot Company nor the names
	  of its contributors may be used to endorse or promote products
	  derived from this software without specific prior written
	  permission.

	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
	"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
	LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
	FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
	PARROT COMPANY BE LIABLE FOR ANY DIRECT, INDIRECT,
	INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
	BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
	OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
	AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
	OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
	OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
	SUCH DAMAGE.
'''
from arsdkprotoparser import ProtoParser
import optparse
import os
import string

#===============================================================================
class Writer(object):
    def __init__(self, fileobj):
        self.fileobj = fileobj

    def write(self, fmt, *args):
        if args:
            self.fileobj.write(fmt % (args))
        else:
            self.fileobj.write(fmt % ())

#===============================================================================
def convertType(type):
    """
    Converts given protobuf type in Swift type
    """
    mapper = { "google.protobuf.Empty": "SwiftProtobuf.Google_Protobuf_Empty",
    "string": "String", "double": "Double", "float": "Float", "int32": "Int32",
    "uint32": "UInt32", "uint64": "UInt64", "sint32": "Int32", "sint64": "Int64",
    "fixed32": "UInt32", "fixed64": "UInt64", "sfixed32": "Int32", "sfixed64": "Int64",
    "bool": "Bool", "bytes": "Data"}
    if type in mapper:
        return mapper[type]
    else:
        return type

def genDecoderListenerProtocolFunc(name, type, out):
    funcName = "on" + string.capwords(name, "_").replace("_","")
    paramName = string.capwords(name, "_").replace("_","")
    paramName = paramName[0].lower() + paramName[1:]
    swiftType = convertType(type)
    out.write("\n")
    out.write("    /// Processes a `%s` event.\n", swiftType)
    out.write("    ///\n")
    out.write("    /// - Parameter %s: event to process\n", paramName)
    out.write("    func %s(_ %s: %s)\n", funcName, paramName, swiftType)

def genDecoderListenerProtocol(event, out):
    """
    Generates code for events decoder listener.
    """
    baseName = event.commandId.replace("_","")
    out.write("/// Listener for `%sDecoder`.\n", baseName)
    out.write("protocol %sDecoderListener: AnyObject {\n", baseName)
    for msg in event.oneOf:
        genDecoderListenerProtocolFunc(msg['id'], msg['type'], out)
    out.write("}\n")

#===============================================================================
def genDecoderCase(name, out):
    caseName = string.capwords(name, "_").replace("_","")
    caseName = caseName[0].lower() + caseName[1:]
    funcName = "on" + string.capwords(name, "_").replace("_","")
    out.write("            case .%s(let event):\n", caseName)
    out.write("                listener?.%s(event)\n", funcName)

def genDecoder(event, out):
    """
    Generates code for event decoder.
    """
    baseName = event.commandId.replace("_","")
    out.write("\n")
    out.write("/// Decoder for %s events.\n", event.serviceId)
    out.write("class %sDecoder: NSObject, ArsdkFeatureGenericCallback {\n\n", baseName)
    out.write("    /// Service identifier.\n")
    out.write("    static let serviceId = \"%s\".serviceId\n\n", event.serviceId)
    out.write("    /// Listener notified when events are decoded.\n")
    out.write("    private weak var listener: %sDecoderListener?\n\n", baseName)
    out.write("    /// Constructor.\n")
    out.write("    ///\n")
    out.write("    /// - Parameter listener: listener notified when events are decoded\n")
    out.write("    init(listener: %sDecoderListener) {\n", baseName)
    out.write("       self.listener = listener\n")
    out.write("    }\n\n")
    out.write("    /// Decodes an event.\n")
    out.write("    ///\n")
    out.write("    /// - Parameter event: event to decode\n")
    out.write("    func decode(_ event: OpaquePointer) {\n")
    out.write("       if ArsdkCommand.getFeatureId(event) == kArsdkFeatureGenericUid {\n")
    out.write("            ArsdkFeatureGeneric.decode(event, callback: self)\n")
    out.write("        }\n")
    out.write("    }\n\n")
    out.write("    func onCustomEvtNonAck(serviceId: UInt, msgNum: UInt, payload: Data) {\n")
    out.write("        processEvent(serviceId: serviceId, payload: payload, isNonAck: true)\n")
    out.write("    }\n\n")
    out.write("    func onCustomEvt(serviceId: UInt, msgNum: UInt, payload: Data!) {\n")
    out.write("        processEvent(serviceId: serviceId, payload: payload, isNonAck: false)\n")
    out.write("    }\n\n")
    out.write("    /// Processes a custom event.\n")
    out.write("    ///\n")
    out.write("    /// - Parameters:\n")
    out.write("    ///    - serviceId: service identifier\n")
    out.write("    ///    - payload: event payload\n")
    out.write("    private func processEvent(serviceId: UInt, payload: Data, isNonAck: Bool) {\n")
    out.write("        guard serviceId == %sDecoder.serviceId else {\n", baseName)
    out.write("            return\n")
    out.write("        }\n")
    out.write("        if let event = try? %s(serializedData: payload) {\n", event.commandId)
    out.write("            if !isNonAck {\n")
    out.write("                ULog.d(ULog.cmdTag, \"%sDecoder event \\(event)\")\n", baseName)
    out.write("            }\n")
    out.write("            switch event.id {\n")
    for msg in event.oneOf:
        genDecoderCase(msg['id'], out)
    out.write("            case .none:\n")
    out.write("                ULog.w(.tag, \"Unknown %s, skipping this event\")\n", event.commandId)
    out.write("            }\n")
    out.write("        }\n")
    out.write("    }\n")
    out.write("}\n")

#===============================================================================
def genEncoder(command, out):
    """
    Generates code for command encoder.
    """
    baseName = command.commandId.replace("_","")
    out.write("\n")
    out.write("/// Decoder for %s commands.\n", command.serviceId)
    out.write("class %sEncoder {\n\n", baseName)
    out.write("    /// Service identifier.\n")
    out.write("    static let serviceId = \"%s\".serviceId\n\n", command.serviceId)
    out.write("    /// Gets encoder for a command.\n")
    out.write("    ///\n")
    out.write("    /// - Parameter command: command to encode\n")
    out.write("    /// - Returns: command encoder, or `nil`\n")
    out.write("    static func encoder(_ command: %s.OneOf_ID) -> ArsdkCommandEncoder? {\n", command.commandId)
    out.write("        ULog.d(.tag, \"%sEncoder command \\(command)\")\n", baseName)
    out.write("        var message = %s()\n", command.commandId)
    out.write("        message.id = command\n")
    out.write("        if let payload = try? message.serializedData() {\n")
    out.write("            return ArsdkFeatureGeneric.customCmdEncoder(serviceId: serviceId,\n")
    out.write("                                                        msgNum: UInt(command.number),\n")
    out.write("                                                        payload: payload)\n")
    out.write("        }\n")
    out.write("        return nil\n")
    out.write("    }\n")
    out.write("}\n")

#===============================================================================
def genCommandNumber(name, number, out):
    caseName = string.capwords(name, "_").replace("_","")
    caseName = caseName[0].lower() + caseName[1:]
    out.write("        case .%s: return %s\n", caseName, number)

def genCommandNumberExtension(command, out):
    """
    Generates code to get a command number.
    """
    out.write("\n")
    out.write("/// Extension to get command field number.\n")
    out.write("extension %s.OneOf_ID {\n", command.commandId)
    out.write("    var number: Int32 {\n")
    out.write("        switch self {\n")
    for msg in command.oneOf:
        genCommandNumber(msg['id'], msg['number'], out)
    out.write("        }\n")
    out.write("    }\n")
    out.write("}\n")

#===============================================================================
def genFieldNumber(fieldName, number, out):
    fieldName = string.capwords(fieldName, "_").replace("_","")
    fieldName = fieldName[0].lower() + fieldName[1:]
    out.write("    static var %sFieldNumber: Int32 { %s }\n", fieldName, number)

def genFieldVar(fieldName, number, out):
    fieldName = string.capwords(fieldName, "_").replace("_","")
    fieldName = fieldName[0].lower() + fieldName[1:]
    out.write("    var %sSelected: Bool {\n", fieldName)
    out.write("        get {\n")
    out.write("            return selectedFields[%s] != nil\n", number)
    out.write("        }\n")
    out.write("        set {\n")
    out.write("            if newValue && selectedFields[%s] == nil {\n", number)
    out.write("                selectedFields[%s] = SwiftProtobuf.Google_Protobuf_Empty()\n", number)
    out.write("            } else if !newValue && selectedFields[%s] != nil {\n", number)
    out.write("                selectedFields.removeValue(forKey: %s)\n", number)
    out.write("            }\n")
    out.write("        }\n")
    out.write("    }\n")

def genMessageExtension(message, out):
    fields = sorted(message.fields.items(), key=lambda field: int(field[1]))
    if not fields:
        return
    hasSelecteFields = "selected_fields" in message.fields
    out.write("extension %s {\n", message.id)
    for fieldName, number in fields:
        genFieldNumber(fieldName, number, out)
    for fieldName, number in fields:
        if hasSelecteFields:
            genFieldVar(fieldName, number, out)

    out.write("}\n")

def genMessagesExtensions(messages, out):
    for message in messages:
        genMessageExtension(message, out)

def genHeader(out):
    out.write("// Generated, do not edit !\n")
    out.write("\n")
    out.write("import Foundation\n")
    out.write("import GroundSdk\n")
    out.write("import SwiftProtobuf\n")
    out.write("\n")

def extractMessagesFromProto(protoFile):
    protoParser = ProtoParser()
    return protoParser.parseFile(protoFile)

def genMessagesExtensionsFile(outdir, infile):
    if not os.path.exists (outdir):
        os.mkdir(outdir)

    messages, command, event = extractMessagesFromProto(infile)

    outfile = os.path.splitext(os.path.basename(infile))[0] + ".pb.ext.swift"

    outfilepath = os.path.join(outdir, outfile)
    with open(outfilepath, "w") as fileobj:
        genHeader(Writer(fileobj))
        if event is not None:
            genDecoderListenerProtocol(event, Writer(fileobj))
            genDecoder(event, Writer(fileobj))
            genCommandNumberExtension(event, Writer(fileobj))
        if command is not None:
            genEncoder(command, Writer(fileobj))
            genCommandNumberExtension(command, Writer(fileobj))
        genMessagesExtensions(messages, Writer(fileobj))

#===============================================================================
#===============================================================================
def main():
    # Parse options
    parser = optparse.OptionParser()
    parser.add_option('-i', '--infile',
              action="store", dest="infile",
              help="path to protobuf file", default="in.proto")
    parser.add_option('-o', '--outdir',
              action="store", dest="outdir",
              help="output directory", default=".")
    options, args = parser.parse_args()

    genMessagesExtensionsFile(options.outdir, options.infile)

#===============================================================================
#===============================================================================
if __name__ == "__main__":
    main()
