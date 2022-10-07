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
import optparse
import string
import pyparsing as pp
from pyparsing import *

# ===============================================================================
# ===============================================================================


class Message(object):
    def __init__(self, id):
        self.id = id
        self.fields = dict()

    def addField(self, id, number):
        self.fields[id] = number

    def dump(self):
        print(self.id)
        for id, number in self.fields.items():
            print("  " + id + " = " + number)

# ===============================================================================
# ===============================================================================


class Command(object):
    def __init__(self, id, serviceId):
        self.commandId = id
        self.serviceId = serviceId
        self.oneOf = []

    def addOneOf(self, id, msgType, number):
        self.oneOf.append({'id': id, 'type': msgType, 'number': number})

    def dump(self):
        print(self.commandId)
        print(self.serviceId)
        for msg in self.oneOf:
            print("  " + msg['id'] + ": " +
                  msg['type'] + " = " + msg['number'])

# ===============================================================================
# ===============================================================================


class ProtoParser(object):

    PACKAGE_NAME_RES = "packageName"
    MSG_ID_RES = "messageId"
    MSG_BODY_RES = "messageBody"
    ONEOF_BODY_RES = "oneOfBody"
    FIELD_ID_RES = "fieldId"
    FIELD_TYPE_RES = "fieldType"
    FIELD_NB_RES = "fieldNumber"
    ENUM_ID_RES = "enumId"

    ident = Word(alphas + "_.", alphanums + "_.")
    integer = Regex(r"[+-]?\d+")

    LBRACE, RBRACE, LBRACK, RBRACK, LPAR, RPAR, EQ, SEMI, COMMA, LESSER, GREATER = map(
        Suppress, "{}[]()=;,<>")

    kwds = """message required optional repeated enum extensions extends extend
              to package service rpc returns true false option import syntax
              reserved oneof map"""
    for kw in kwds.split():
        exec("{}_ = Keyword('{}')".format(kw.upper(), kw))

    messageBody = Forward()

    messageDefn = (MESSAGE_ - ident(MSG_ID_RES)
                   + LBRACE + messageBody(MSG_BODY_RES) + RBRACE)

    oneOfBody = Forward()

    oneOfDefn = ONEOF_ - ident + LBRACE + oneOfBody(ONEOF_BODY_RES) + RBRACE

    mapDefn = (
        MAP_
        - LESSER
        + oneOf(
            """ int32 int64 uint32 uint64 sint32 sint64
                fixed32 fixed64 sfixed32 sfixed64 bool string"""
        )
        + COMMA
        + ident
        + GREATER
    )

    typespec = (
        oneOf(
            """double float int32 int64 uint32 uint64 sint32 sint64
                fixed32 fixed64 sfixed32 sfixed64 bool string bytes"""
        )
        | mapDefn
        | ident
    )

    rvalue = integer | TRUE_ | FALSE_ | ident
    fieldDirective = LBRACK + \
        Group(Optional(LPAR) + ident + Optional(RPAR) +
              EQ + Group(rvalue | ZeroOrMore(quotedString))) + RBRACK
    fieldDefnPrefix = REQUIRED_ | OPTIONAL_ | REPEATED_
    fieldDefn = (
        Optional(fieldDefnPrefix)
        + typespec(FIELD_TYPE_RES)
        + ident(FIELD_ID_RES)
        + EQ
        + integer(FIELD_NB_RES)
        + ZeroOrMore(fieldDirective)
        + SEMI
    )

    optionDirective = OPTION_ - \
        Optional(LPAR) + ident + Optional(RPAR) + \
        EQ + ZeroOrMore(quotedString) + SEMI

    # reservedDefn ::= 'reserved' integer 'to' integer ';'
    # reservedDefn ::= 'reserved' integer ',' integer ';'
    # reservedDefn ::= 'reserved' integer ',' integer ',' 'to', integer ';'
    reservedDefn = RESERVED_ - integer + \
        ZeroOrMore(Group(TO_ | COMMA) + integer) + SEMI

    # enumDefn ::= 'enum' ident '{' { ident '=' integer ';' }* '}'
    enumDefn = (
        ENUM_
        - ident(ENUM_ID_RES)
        + LBRACE
        + Dict(
            ZeroOrMore(
                Group(ident + EQ + integer + ZeroOrMore(fieldDirective) + SEMI
                      | optionDirective | reservedDefn)
            )
        )
        + RBRACE
    )

    # extensionsDefn ::= 'extensions' integer 'to' integer ';'
    extensionsDefn = EXTENSIONS_ - integer + TO_ + integer + SEMI

    # messageExtension ::= 'extend' ident '{' messageBody '}'
    messageExtension = EXTEND_ - ident + LBRACE + messageBody + RBRACE

    # oneOfBody ::= { fieldDefn }*
    oneOfBody << Group(
        ZeroOrMore(
            Group(fieldDefn)
        )
    )

    # messageBody ::= { fieldDefn | enumDefn | messageDefn | extensionsDefn| reservedDef | messageExtension | oneOfDefn | optionDirective }*
    messageBody << Group(
        ZeroOrMore(
            Group(fieldDefn | enumDefn | messageDefn | extensionsDefn
                  | reservedDefn | messageExtension | oneOfDefn | optionDirective)
        )
    )

    # methodDefn ::= 'rpc' ident '(' [ ident ] ')' 'returns' '(' [ ident ] ')' ';'
    methodDefn = (
        RPC_
        - ident
        + LPAR
        + Optional(ident)
        + RPAR
        + RETURNS_
        + LPAR
        + Optional(ident)
        + RPAR
    )

    # serviceDefn ::= 'service' ident '{' methodDefn* '}'
    serviceDefn = (
        SERVICE_ - ident + LBRACE + ZeroOrMore(Group(methodDefn)) + RBRACE
    )

    syntaxDefn = SYNTAX_ + EQ - quotedString + SEMI

    # packageDirective ::= 'package' ident ';'
    packageDirective = PACKAGE_ - ident(PACKAGE_NAME_RES) + SEMI

    importDirective = IMPORT_ - quotedString + SEMI

    topLevelStatement = Group(
        messageDefn
        | messageExtension
        | enumDefn
        | serviceDefn
        | importDirective
        | optionDirective
        | syntaxDefn
        | packageDirective
    )

    def parseFile(self, filepath):
        """
        Parses protobuf files.
        """
        parser = ZeroOrMore(self.topLevelStatement)
        parser.ignore(javaStyleComment)
        parseResults = parser.parseFile(filepath, parseAll=False)

        packageName = self.getPackageName(parseResults)
        baseName = self.getBaseName(parseResults)
        messages = self.extractMessages(
            parseResults=parseResults, baseName=baseName)

        command = self.extractCmd(name="Command", parseResults=parseResults,
                                  packageName=packageName, baseName=baseName, messages=messages)
        event = self.extractCmd(name="Event", parseResults=parseResults,
                                packageName=packageName, baseName=baseName, messages=messages)

        return messages, command, event

    def getPackageName(self, parseResults):
        """
        Returns protobuf package name.
        """
        for item in parseResults:
            if self.PACKAGE_NAME_RES in item:
                return item[self.PACKAGE_NAME_RES]
        return ""

    def getBaseName(self, parseResults):
        """
        Returns protobuf messages base name.
        """
        for item in parseResults:
            if self.PACKAGE_NAME_RES in item:
                return string.capwords(item[self.PACKAGE_NAME_RES], ".").replace(".", "_")
        return ""

    def extractMessages(self, parseResults, baseName):
        """
        Returns all messages found in protobuf parse results.
        The returned type is a list table of `Message`.
        """
        messages = []
        self._extractMessages(parseResults, messages, baseName)
        return messages

    def _extractMessages(self, resultItem, messages, baseName, parentMessage=None):
        for item in resultItem:
            if self.MSG_ID_RES in item and self.MSG_BODY_RES in item:
                messageId = item[self.MSG_ID_RES]
                if parentMessage is None:
                    messageId = baseName + "_" + messageId
                else:
                    messageId = parentMessage.id + "." + messageId
                message = Message(messageId)
                self._extractMessages(
                    item[self.MSG_BODY_RES], messages, messageId, message)
                messages.append(message)
            if self.ENUM_ID_RES in item:
                messageId = item[self.ENUM_ID_RES]
                if parentMessage is None:
                    messageId = baseName + "_" + messageId
                else:
                    messageId = parentMessage.id + "." + messageId
                message = Message(messageId)
                messages.append(message)
            if self.ONEOF_BODY_RES in item:
                self._extractMessages(
                    item[self.ONEOF_BODY_RES], messages, baseName, parentMessage)
            if self.FIELD_ID_RES in item and self.FIELD_NB_RES in item:
                if parentMessage is not None:
                    parentMessage.addField(
                        id=item[self.FIELD_ID_RES], number=item[self.FIELD_NB_RES])

    def extractCmd(self, name, parseResults, packageName, baseName, messages):
        """
        Returns arsdk commands matching a given name defined in the protobuf file.
        """
        cmd = None
        for item in parseResults:
            if self.MSG_ID_RES in item and self.MSG_BODY_RES in item and item[self.MSG_ID_RES] == name:
                cmdId = baseName + "_" + item[self.MSG_ID_RES]
                serviceId = packageName + "." + item[self.MSG_ID_RES]
                cmd = Command(cmdId, serviceId)
                self.extractCmdContent(item[self.MSG_BODY_RES], cmd, messages)
        return cmd

    def extractCmdContent(self, resultItem, cmd, messages):
        """
        Fill arsdk commands with content of oneOf fields.
        """
        for item in resultItem:
            if self.ONEOF_BODY_RES in item:
                for oneOfItem in item[self.ONEOF_BODY_RES]:
                    if self.FIELD_ID_RES in oneOfItem and self.FIELD_NB_RES in oneOfItem and self.FIELD_TYPE_RES in oneOfItem:
                        if isinstance(oneOfItem[self.FIELD_TYPE_RES], ParseResults):
                            fieldType = str(oneOfItem[self.FIELD_TYPE_RES][0])
                        else:
                            fieldType = oneOfItem[self.FIELD_TYPE_RES]
                        msgType = self.normalizeType(
                            fieldType, cmd.commandId, messages)
                        cmd.addOneOf(
                            str(oneOfItem[self.FIELD_ID_RES]), msgType, oneOfItem[self.FIELD_NB_RES])

    def normalizeType(self, messageType, parentType, messages):
        """
        Returns field full type name.
        """
        # exact match
        for message in messages:
            if message.id == str(parentType + "." + messageType):
                return message.id
        # end match
        for message in messages:
            if message.id.endswith("_" + messageType):
                return message.id
        return string.capwords(messageType, ".").replace(".", "_", messageType.count(".") - 1)


# ===============================================================================
# ===============================================================================
def main():
    # Parse options
    parser = optparse.OptionParser()
    parser.add_option('-i', '--input',
                      action="store", dest="inputpath",
                      help="path to protobuf file", default="in.proto")
    parser.add_option('-o', '--output',
                      action="store", dest="outpath",
                      help="output directory", default="out")
    options, args = parser.parse_args()

    # Parse protobuf file
    protoParser = ProtoParser()
    messages, command, event = protoParser.parseFile(options.inputpath)

    # print results
    for message in messages:
        message.dump()
    if command is not None:
        command.dump()
    if event is not None:
        event.dump()


# ===============================================================================
# ===============================================================================
if __name__ == "__main__":
    main()
