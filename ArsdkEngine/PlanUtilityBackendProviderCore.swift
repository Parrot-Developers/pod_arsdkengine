// Copyright (C) 2022 Parrot Drones SAS
//
//    Redistribution and use in source and binary forms, with or without
//    modification, are permitted provided that the following conditions
//    are met:
//    * Redistributions of source code must retain the above copyright
//      notice, this list of conditions and the following disclaimer.
//    * Redistributions in binary form must reproduce the above copyright
//      notice, this list of conditions and the following disclaimer in
//      the documentation and/or other materials provided with the
//      distribution.
//    * Neither the name of the Parrot Company nor the names
//      of its contributors may be used to endorse or promote products
//      derived from this software without specific prior written
//      permission.
//
//    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
//    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
//    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
//    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
//    PARROT COMPANY BE LIABLE FOR ANY DIRECT, INDIRECT,
//    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
//    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
//    OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
//    AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
//    OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
//    OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
//    SUCH DAMAGE.

import Foundation
import GroundSdk
import SdkCore

/// The Plan generator/parser backend provider core that bridges GroundSdk values with
/// engine values.
class PlanUtilityBackendProviderCore: PlanUtility {

    let desc: UtilityCoreDescriptor = Utilities.planUtilityProvider

    /// Constructor
    public init() {
    }

    func generate(plan: Plan, at fileUrl: URL, groundStation: String) throws {
        try FileManager.default.createDirectory(at: fileUrl.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        guard !FileManager.default.fileExists(atPath: fileUrl.path) else {
            throw Plan.Error.fileExists
        }
        let resultData = try generate(plan: plan, groundStation: groundStation)
        try resultData.write(to: fileUrl)
    }

    func generate(plan: Plan, groundStation: String) throws -> Data {
        guard !plan.items.isEmpty else {
            throw Plan.Error.noItems
        }
        let encoder = JSONEncoder()
        // MavlinkCommands do not convert to valid JSON values and thus this
        // strategy is necessary
        encoder.nonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "Infinity",
                                                                      negativeInfinity: "-Infinity",
                                                                      nan: "NaN")
        var commandIndex = 0
        var configIndex = 0
        var missionItems = [PlanFormat.PlanItemWithIndexAndConfig]()
        var configItems = [String: Config]()
        let items = plan.items.map(Item.init)
        for index in (items.startIndex..<items.endIndex) {
            let item = items[index]
            switch item {
            case .command(let command):
                let config = index != items.startIndex
                && configIndex > 0 && items[index - 1].isConfig ? configIndex - 1 : nil
                missionItems.append(
                    PlanFormat.PlanItemWithIndexAndConfig(frame: command.frame.rawValue,
                                                          autocontinue: command.autocontinue,
                                                          type: command.rawType,
                                                          parametres: command.parameters,
                                                          index: commandIndex,
                                                          config: config)
                )
                commandIndex += 1
            case .config(let config):
                configItems["\(configIndex)"] = config
                configIndex += 1
            }
        }
        let planFormat = PlanFormat(staticConfig: plan.staticConfig.map(StaticConfig.init),
                              mission: PlanFormat.Mission(items: missionItems),
                              configs: PlanFormat.Configs(items: configItems),
                              version: Plan.Version,
                              filetype: Plan.Filetype,
                              groundStation: groundStation,
                              itemsVersion: Plan.ItemsVersion)
        let resultData = try encoder.encode(planFormat)
        return resultData
    }

    func parse(fileUrl: URL) throws -> Plan {
        guard FileManager.default.fileExists(atPath: fileUrl.path) else {
            throw Plan.Error.fileDoesNotExist
        }
        let data = try Data(contentsOf: fileUrl, options: .uncached)
        return try parse(planData: data)
    }

    func parse(planData: Data) throws -> Plan {
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(positiveInfinity: "Infinity",
                                                                        negativeInfinity: "-Infinity",
                                                                        nan: "NaN")
        let planFormat = try decoder.decode(PlanFormat.self, from: planData)
        return try Plan(planFormat)
    }

    /// The Plan format representation.
    fileprivate struct PlanFormat: Codable {
        struct Mission: Codable {
            let items: [PlanItemWithIndexAndConfig]
        }
        struct Configs: Codable {
            let items: [String: Config]
        }
        let staticConfig: StaticConfig?
        let mission: Mission
        let configs: Configs
        let version: String
        let filetype: String
        let groundStation: String
        let itemsVersion: String
    }

    /// The Plan.Item equivalent in the engine world.
    fileprivate enum Item: Encodable {
        case command(MavlinkStandard.MavlinkCommand)
        case config(Config)

        var isConfig: Bool {
            if case .config = self {
                return true
            }
            return false
        }

        init(_ item: Plan.Item) {
            switch item {
            case .config(let config):
                self = .config(PlanUtilityBackendProviderCore.Config(config))
            case .command(let command):
                self = .command(command)
            }
        }
    }

    /// The Plan.Config equivalent in the engine world.
    fileprivate struct Config: Codable {
        let obstacleAvoidance: Bool?
        let evCompensation: Arsdk_Camera_EvCompensation?
        let whiteBalance: Arsdk_Camera_WhiteBalanceMode?
        let photoResolution: Arsdk_Camera_PhotoResolution?
        let videoResolution: Arsdk_Camera_VideoResolution?
        let frameRate: Arsdk_Camera_Framerate?

        init(_ other: Plan.Config) {
            self.obstacleAvoidance = other.obstacleAvoidance
            self.evCompensation = other.evCompensation.map {
                Camera2EvCompensation.arsdkMapper.map(from: $0)!
            }
            self.whiteBalance = other.whiteBalance.map {
                Camera2WhiteBalanceMode.arsdkMapper.map(from: $0)!
            }
            self.photoResolution = other.photoResolution.map {
                Camera2PhotoResolution.arsdkMapper.map(from: $0)!
            }
            self.videoResolution = other.videoResolution.map {
                Camera2RecordingResolution.arsdkMapper.map(from: $0)!
            }
            self.frameRate = other.frameRate.map {
                Camera2RecordingFramerate.arsdkMapper.map(from: $0)!
            }
        }
    }

    /// The Plan.StaticConfig equivalent in the engine world.
    fileprivate struct StaticConfig: Codable {
        let customRth: Bool?
        let rthType: ArsdkFeatureRthHomeType?
        let rthAltitude: Double?
        let rthEndAltitude: Double?
        let rthOnDisconnection: Bool?
        let landAtEndOfRth: ArsdkFeatureRthEndingBehavior?
        let digitalSignature: Arsdk_Camera_DigitalSignature?
        let customId: String?
        let customTitle: String?

        init(_ other: Plan.StaticConfig) {
            self.customRth = other.customRth
            if let rthType = other.rthType {
                switch rthType {
                case .none:
                    self.rthType = .takeoff
                case .customPosition:
                    self.rthType = .custom
                case .takeOffPosition:
                    self.rthType = .takeoff
                case .controllerPosition:
                    self.rthType = .pilot
                case .trackedTargetPosition:
                    self.rthType = .followee
                }
            } else {
                self.rthType = nil
            }
            self.rthAltitude = other.rthAltitude
            self.rthEndAltitude = other.rthEndAltitude
            switch other.rthEndingBehavior {
            case .landing:
                self.landAtEndOfRth = .landing
            case .hovering:
                self.landAtEndOfRth = .hovering
            case .none:
                self.landAtEndOfRth = nil
            }
            self.rthOnDisconnection = other.disconnectionPolicy.flatMap { $0 == .returnToHome }
            self.digitalSignature = other.digitalSignature.map {
                Camera2DigitalSignature.arsdkMapper.map(from: $0)!
            }
            self.customId = other.customId
            self.customTitle = other.customTitle
        }
    }
}

fileprivate extension Plan {
    init(_ plan: PlanUtilityBackendProviderCore.PlanFormat) throws {
        var items = [Plan.Item]()
        items.reserveCapacity(plan.mission.items.count + plan.configs.items.count)
        for item in plan.mission.items {
            guard let frame = MavlinkStandard.MavlinkCommand.Frame(rawValue: item.frame) else {
                throw Plan.Error.parseError("Unsupported mavlink command itemframe")
            }
            let command = try MavlinkStandard.MavlinkCommand.create(rawType: item.type,
                                                                    frame: frame,
                                                                    parameters: item.parametres)
            if let configIndex = item.config, let config = plan.configs.items["\(configIndex)"] {
                items.append(Plan.Item.config(Plan.Config(config)))
            }
            items.append(Plan.Item.command(command))
        }
        self.init(staticConfig: plan.staticConfig.map(Plan.StaticConfig.init), items: items)
    }
}

fileprivate extension Plan.StaticConfig {
    init(_ staticConfig: PlanUtilityBackendProviderCore.StaticConfig) {
        let rthType: ReturnHomeTarget?
        if let otherRthType = staticConfig.rthType {
            switch otherRthType {
            case .none:
                rthType = ReturnHomeTarget.none
            case .custom:
                rthType = .customPosition
            case .takeoff:
                rthType = .takeOffPosition
            case .pilot:
                rthType = .controllerPosition
            case .followee:
                rthType = .trackedTargetPosition
            case .sdkCoreUnknown:
                fallthrough
            @unknown default:
                rthType = nil
            }
        } else {
            rthType = nil
        }
        let returnHomeEndingBehavior: ReturnHomeEndingBehavior?
        if let otherLandAtEndOfRth = staticConfig.landAtEndOfRth {
            switch otherLandAtEndOfRth {
            case .landing:
                returnHomeEndingBehavior = .landing
            case .hovering:
                returnHomeEndingBehavior = .hovering
            case .sdkCoreUnknown:
                fallthrough
            @unknown default:
                returnHomeEndingBehavior = nil
            }
        } else {
            returnHomeEndingBehavior = nil
        }
        self.init(customRth: staticConfig.customRth,
                  rthType: rthType,
                  rthAltitude: staticConfig.rthAltitude,
                  rthEndAltitude: staticConfig.rthEndAltitude,
                  disconnectionPolicy: staticConfig.rthOnDisconnection.map {
            $0 ? FlightPlanDisconnectionPolicy.returnToHome : FlightPlanDisconnectionPolicy.continue
        },
                  rthEndingBehavior: returnHomeEndingBehavior,
                  digitalSignature: staticConfig.digitalSignature.flatMap(
                    Camera2DigitalSignature.arsdkMapper.reverseMap(from:)))
    }
}

fileprivate extension Plan.Config {
    init(_ config: PlanUtilityBackendProviderCore.Config) {
        self.init(obstacleAvoidance: config.obstacleAvoidance,
                  evCompensation: config.evCompensation.flatMap(
            Camera2EvCompensation.arsdkMapper.reverseMap(from:)),
                  whiteBalance: config.whiteBalance.flatMap(
            Camera2WhiteBalanceMode.arsdkMapper.reverseMap(from:)),
                  photoResolution: config.photoResolution.flatMap(
            Camera2PhotoResolution.arsdkMapper.reverseMap(from:)),
                  videoResolution: config.videoResolution.flatMap(
                    Camera2RecordingResolution.arsdkMapper.reverseMap(from:)),
                  frameRate: config.frameRate.flatMap(
            Camera2RecordingFramerate.arsdkMapper.reverseMap(from:))
        )
    }
}

private extension PlanUtilityBackendProviderCore.PlanFormat {
    enum CodingKeys: String, CodingKey {
        case staticConfig
        case mission
        case version
        case filetype = "fileType"
        case groundStation
        case itemsVersion
        case configs
    }

    enum ItemsCodingKeys: String, CodingKey {
        case items
    }

    enum ConfigCodingKeys: String, CodingKey {
        case items
    }

    struct PlanItemWithIndexAndConfig: Codable {
        enum CodingKeys: String, CodingKey {
            case frame = "AltitudeMode"
            case autocontinue
            case type = "command"
            case parameters = "params"
            case index
            case config
        }
        let frame: UInt
        let autocontinue: Int
        let type: Int
        let parametres: [Double]
        let index: Int
        let config: Int?

        internal init(frame: UInt, autocontinue: Int, type: Int, parametres: [Double],
                      index: Int, config: Int? = nil) {
            self.frame = frame
            self.autocontinue = autocontinue
            self.type = type
            self.parametres = parametres
            self.index = index
            self.config = config
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.frame = try container.decode(UInt.self, forKey: .frame)
            self.autocontinue = try container.decode(Int.self, forKey: .autocontinue)
            self.type = try container.decode(Int.self, forKey: .type)
            self.parametres = try container.decode([Double].self, forKey: .parameters)
            self.index = try container.decode(Int.self, forKey: .index)
            self.config = try container.decodeIfPresent(Int.self, forKey: .config)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.frame, forKey: .frame)
            try container.encode(self.autocontinue, forKey: .autocontinue)
            try container.encode(self.type, forKey: .type)
            try container.encode(self.parametres, forKey: .parameters)
            try container.encode(self.index, forKey: .index)
            try container.encodeIfPresent(self.config, forKey: .config)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.staticConfig = try container.decodeIfPresent(PlanUtilityBackendProviderCore.StaticConfig.self,
                                                          forKey: .staticConfig)
        self.version = try container.decode(String.self, forKey: .version)
        self.filetype = try container.decode(String.self, forKey: .filetype)
        self.groundStation = try container.decode(String.self, forKey: .groundStation)
        self.itemsVersion = try container.decode(String.self, forKey: .itemsVersion)
        self.mission = try container.decode(Mission.self, forKey: .mission)
        self.configs = try container.decode(Configs.self, forKey: .configs)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(self.staticConfig, forKey: .staticConfig)
        try container.encode(self.version, forKey: .version)
        try container.encode(self.filetype, forKey: .filetype)
        try container.encode(self.groundStation, forKey: .groundStation)
        try container.encode(self.itemsVersion, forKey: .itemsVersion)
        try container.encode(self.mission, forKey: .mission)
        try container.encode(self.configs, forKey: .configs)
    }
}

private extension PlanUtilityBackendProviderCore.Item {
    enum CodingKeys: String, CodingKey {
        case command
        case config
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .command(let command):
            try container.encode(command, forKey: .command)
        case .config(let config):
            try container.encode(config, forKey: .config)
        }
    }
}

private extension PlanUtilityBackendProviderCore.Config {
    enum CodingKeys: String, CodingKey {
        case obstacleAvoidance
        case evCompensation
        case whiteBalance
        case photoResolution
        case videoResolution
        case frameRate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.obstacleAvoidance = try container.decodeIfPresent(Bool.self, forKey: .obstacleAvoidance)
        self.evCompensation = try container.decodeIfPresent(Int.self, forKey: .evCompensation)
            .flatMap(Arsdk_Camera_EvCompensation.init(rawValue:))
        self.whiteBalance = try container.decodeIfPresent(Int.self, forKey: .whiteBalance)
            .flatMap(Arsdk_Camera_WhiteBalanceMode.init(rawValue:))
        self.photoResolution = try container.decodeIfPresent(Int.self, forKey: .photoResolution)
            .flatMap(Arsdk_Camera_PhotoResolution.init(rawValue:))
        self.videoResolution = try container.decodeIfPresent(Int.self, forKey: .videoResolution)
            .flatMap(Arsdk_Camera_VideoResolution.init(rawValue:))
        self.frameRate = try container.decodeIfPresent(Int.self, forKey: .frameRate)
            .flatMap(Arsdk_Camera_Framerate.init(rawValue:))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(self.obstacleAvoidance, forKey: .obstacleAvoidance)
        try container.encodeIfPresent(self.evCompensation?.rawValue, forKey: .evCompensation)
        try container.encodeIfPresent(self.whiteBalance?.rawValue, forKey: .whiteBalance)
        try container.encodeIfPresent(self.photoResolution?.rawValue, forKey: .photoResolution)
        try container.encodeIfPresent(self.videoResolution?.rawValue, forKey: .videoResolution)
        try container.encodeIfPresent(self.frameRate?.rawValue, forKey: .frameRate)
    }
}

private extension PlanUtilityBackendProviderCore.StaticConfig {
    enum CodingKeys: String, CodingKey {
        case customRth = "customRth"
        case rthType = "rthType"
        case rthAltitude = "rthAltitude"
        case rthEndAltitude = "rthEndAltitude"
        case rthOnDisconnection = "rthOnDisconnection"
        case landAtEndOfRth = "landAtEndOfRth"
        case digitalSignature  = "digitalSignature"
        case customId = "customId"
        case customTitle = "customTitle"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.customRth = try container.decodeIfPresent(Bool.self, forKey: .customRth)
        self.rthType = try container.decodeIfPresent(Int.self, forKey: .rthType)
            .flatMap(ArsdkFeatureRthHomeType.init(rawValue:))
        self.rthAltitude = try container.decodeIfPresent(Double.self, forKey: .rthAltitude)
        self.rthEndAltitude = try container.decodeIfPresent(Double.self, forKey: .rthEndAltitude)
        self.rthOnDisconnection = try container.decodeIfPresent(Bool.self, forKey: .rthOnDisconnection)
        self.landAtEndOfRth = try container.decodeIfPresent(Int.self, forKey: .landAtEndOfRth)
            .flatMap(ArsdkFeatureRthEndingBehavior.init(rawValue:))
        self.digitalSignature = try container.decodeIfPresent(Int.self, forKey: .digitalSignature)
            .flatMap(Arsdk_Camera_DigitalSignature.init(rawValue:))
        self.customId = try container.decodeIfPresent(String.self, forKey: .customId)
        self.customTitle = try container.decodeIfPresent(String.self, forKey: .customTitle)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(self.customRth, forKey: .customRth)
        try container.encodeIfPresent(self.rthType?.rawValue, forKey: .rthType)
        try container.encodeIfPresent(self.rthAltitude, forKey: .rthAltitude)
        try container.encodeIfPresent(self.rthEndAltitude, forKey: .rthEndAltitude)
        try container.encodeIfPresent(self.rthOnDisconnection, forKey: .rthOnDisconnection)
        try container.encodeIfPresent(self.landAtEndOfRth?.rawValue, forKey: .landAtEndOfRth)
        try container.encodeIfPresent(self.digitalSignature?.rawValue, forKey: .digitalSignature)
        try container.encodeIfPresent(self.customId, forKey: .customId)
        try container.encodeIfPresent(self.customTitle, forKey: .customTitle)
    }
}
