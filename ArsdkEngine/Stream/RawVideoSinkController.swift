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

/// Controller of RawVideoSink.
public class RawVideoSinkController: SinkController, RawVideoSinkBackend {

    /// Raw video sink.
    var rawVideoSinkCore: RawVideoSinkCore!

    /// Sdkcore Sink.
    private var sdkCoreSink: SdkCoreRawVideoSink!

    /// Raw video sink Configuration.
    private let config: RawVideoSinkConfig

    /// Media availability listener handle.
    private var mediaListener: StreamController.ListenerHandle?

    /// Media Info
    /// Set a new media info will stop the sink on the older media and start a new sink on the new media set.
    private var _mediaInfo: SdkCoreMediaInfo?
    private var mediaInfo: SdkCoreMediaInfo? {
        get {
            return _mediaInfo
        }
        set {
            guard mediaInfo != newValue else { return }

            if mediaInfo != nil {
                // stop sink on the old media
                sdkCoreSink?.stop()
            }

            _mediaInfo = newValue
            if let mediaInfo = newValue {
                // start sink on the new media
                sdkcoreStream?.start(sdkCoreSink, mediaId: UInt32(mediaInfo.mediaId))
            }
        }
    }

    /// Constructor.
    ///
    /// - Parameters:
    ///    - streamCtrl: stream controller providing the sdkcoreStream.
    ///    - config: raw video sink configuration
    public init(streamCtrl: StreamController, config: RawVideoSinkConfig) {
        self.config = config
        super.init(streamCtrl: streamCtrl)

        rawVideoSinkCore = RawVideoSinkCore(config: config, backend: self)

        sdkCoreSink = SdkCoreRawVideoSink(queueSize: UInt32(config.frameQueueSize), listener: self)
    }

    override func onSdkCoreStreamAvailable(sdkCoreStream: ArsdkStream) {
        super.onSdkCoreStreamAvailable(sdkCoreStream: sdkCoreStream)
        mediaListener = streamCtrl.register(streamWouldOpen: {},
                                            sdkcoreStreamStateDidChange: { _ in },
                                            availableMediaDidChange: { [weak self] in self?.lookupMedia() })
        lookupMedia()
    }

    override func onSdkCoreStreamUnavailable() {
        super.onSdkCoreStreamUnavailable()

        // unregister listener
        mediaListener = nil
        mediaInfo = nil
    }

    /// Finds any media matching the `config` from the stream's available media and updates `mediaInfo` accordingly.
    private func lookupMedia() {
        guard let sdkcoreStream = sdkcoreStream else {
            assertionFailure("sdkcoreStream is nil")
            return
        }
        mediaInfo = sdkcoreStream.medias.first(where: { $0.value is SdkCoreRawInfo })?.value as SdkCoreMediaInfo?
    }
}

/// Frame data plane implementation.
class RawVideoSinkFramePlaneCore: RawVideoSinkFramePlane {

    var data: Data

    var stride: UInt64

    init(data: Data, stride: UInt64) {
        self.data = data
        self.stride = stride
    }
}

/// Raw video sink frame implementation.
class RawVideoSinkFrameCore: RawVideoSinkFrame {

    let sdkcoreFrame: SdkCoreFrame

    var nativePtr: UnsafeMutableRawPointer { sdkcoreFrame.nativePtr }

    var planes: [RawVideoSinkFramePlane]

    var timestamp: UInt64 { UInt64(sdkcoreFrame.frameInfo.timestamp) }

    var timeScale: UInt { UInt(sdkcoreFrame.frameInfo.timeScale) }

    var captureTimestamp: UInt64 { UInt64(sdkcoreFrame.frameInfo.captureTimestamp) }

    var silent: Bool { sdkcoreFrame.frameInfo.silent }

    var visualError: Bool { sdkcoreFrame.frameInfo.visualError }

    var _metadata: Vmeta_TimedMetadata?
    var metadata: Vmeta_TimedMetadata? {
        if _metadata == nil {
            if let buf = sdkcoreFrame.metadataProtobuf {
                do {
                    _metadata = try Vmeta_TimedMetadata(serializedData: Data(buf))
                } catch {
                    print("Failed to extract protobuf data from video frame metadata")
                }
            }
        }

        return _metadata
    }

    init(sdkcoreFrame: SdkCoreFrame) {
        self.sdkcoreFrame = sdkcoreFrame
        planes = [RawVideoSinkFramePlaneCore]()
        for idx: Int in 0..<sdkcoreFrame.planes.count {
            planes.append(RawVideoSinkFramePlaneCore(data: sdkcoreFrame.planes[idx],
                                                     stride: UInt64(truncating: sdkcoreFrame.strides[idx])))
        }
    }

    func copy() -> RawVideoSinkFrame {
        return RawVideoSinkFrameCore(sdkcoreFrame: sdkcoreFrame.copy())
    }
}

/// Extension to listen to internal sink events.
extension RawVideoSinkController: SdkCoreRawVideoSinkListener {

    public func onStart() {
        guard let mediaInfo = mediaInfo else { fatalError("mediaInfo nil") }
        guard let videoFormat = mediaInfo.toGsdk() else { fatalError("videoFormat nil") }

        config.listener?.didStart(sink: self.rawVideoSinkCore, videoFormat: videoFormat)
    }

    public func onStop() {
        config.listener?.didStop(sink: self.rawVideoSinkCore)
    }

    public func onFrame(_ frame: SdkCoreFrame) {
        config.dispatchQueue.async { [weak self] in
            if let self = self {
                self.config.listener?.frameReady(sink: self.rawVideoSinkCore,
                                                 frame: RawVideoSinkFrameCore(sdkcoreFrame: frame))
            }
        }
    }
}

extension SdkCoreMediaInfo {

    private func getDisplayPrimaries() -> VideoFormatColorPrimaries {
        guard let videoInfo = self as? SdkCoreVideoInfo else { fatalError("self is not SdkCoreVideoInfo") }

        if videoInfo.masteringDisplayColorVolume.displayPrimaries != .unknown {
            return VideoFormatColorPrimaries.fromArsdk(videoInfo.masteringDisplayColorVolume.displayPrimaries)!
        }
        // displayPrimaries if defined

        guard let whitePointF = videoInfo.masteringDisplayColorVolume.whitePoint else { fatalError("whitePoint nil") }
        guard let colorPrimaries = videoInfo.masteringDisplayColorVolume.colorPrimaries else {
            fatalError("colorPrimaries nil")
        }

        let whitePoint = VideoFormatChromaticityCoordinatesCore(x: Double(whitePointF.x),
                                                                y: Double(whitePointF.y))

        let red = VideoFormatChromaticityCoordinatesCore(x: Double(colorPrimaries[0].x),
                                                         y: Double(colorPrimaries[0].y))
        let green = VideoFormatChromaticityCoordinatesCore(x: Double(colorPrimaries[1].x),
                                                           y: Double(colorPrimaries[1].y))
        let blue = VideoFormatChromaticityCoordinatesCore(x: Double(colorPrimaries[2].x),
                                                          y: Double(colorPrimaries[2].y))

        return .custom(whitePoint: whitePoint, red: red, green: green, blue: blue)
    }

    func toGsdk() -> VideoFormat? {
        guard let videoInfo = self as? SdkCoreVideoInfo else { return nil }

        var format: VideoFormatDescriptor?
        if let raw = self as? SdkCoreRawInfo {
            format = VideoFormatRawCore(pixelFormat: VideoFormatRawPixelFormat(fromArsdk: raw.pixFormat),
                                        pixelOrder: VideoFormatRawPixelOrder(fromArsdk: raw.pixOrder),
                                        pixelLayout: VideoFormatRawPixelLayout(fromArsdk: raw.pixLayout),
                                        pixelSize: raw.pixSize,
                                        dataLayout: VideoFormatRawDataLayout(fromArsdk: raw.dataLayout),
                                        dataPadding: raw.dataPadLow ? .low : .high,
                                        dataEndianness: raw.dataLittleEndian ? .little : .big,
                                        dataSize: UInt32(raw.dataSize))
        }
        guard let format = format else { fatalError("bad video format") }

        let resolution = VideoFormatResolutionCore(width: UInt64(videoInfo.resolution.width),
                                                   height: UInt64(videoInfo.resolution.height))
        let framerate = VideoFormatFramerateCore(frames: UInt64(videoInfo.framerate.numerator),
                                                 period: UInt64(videoInfo.framerate.denominator))
        let colorPrimaries = VideoFormatColorPrimaries.fromArsdk(videoInfo.colorPrimaries)
        let aspectRatio = VideoFormatAspectRatioCore(width: UInt64(videoInfo.sar.width),
                                                     height: UInt64(videoInfo.sar.height))

        let displayPrimaries = getDisplayPrimaries()

        let minDisplayMasteringLuminance = Double(videoInfo.masteringDisplayColorVolume.minDisplayMasteringLuminance)
        let maxDisplayMasteringLuminance = Double(videoInfo.masteringDisplayColorVolume.maxDisplayMasteringLuminance)
        let luminanceRange = minDisplayMasteringLuminance...maxDisplayMasteringLuminance
        let masteringDisplayColorVolume = VideoFormatMasteringDisplayColorVolumeCore(colorPrimaries: displayPrimaries,
                                                                                     luminanceRange: luminanceRange)

        let contentLightLevel = videoInfo.contentLightLevel != nil ? VideoFormatContentLightLevelCore(
            maxContentLightLevel: Int64(videoInfo.contentLightLevel!.maxContentLightLevel),
            maxFrameAverageLightLevel: Int64(videoInfo.contentLightLevel!.maxFrameAverageLightLevel)) : nil

        return VideoFormatCore(format: format,
                               resolution: resolution,
                               framerate: framerate,
                               bitDepth: videoInfo.bitDepth,
                               fullColorRange: videoInfo.fullRange,
                               colorPrimaries: colorPrimaries,
                               transferFunction: VideoFormatTransferFunction(fromArsdk: videoInfo.transferFunction),
                               matrixCoefficients: VideoFormatMatrixCoefficients(fromArsdk: videoInfo.matrixCoefs),
                               dynamicRange: VideoFormatDynamicRange(fromArsdk: videoInfo.dynamicRange),
                               toneMapping: VideoFormatToneMapping(fromArsdk: videoInfo.toneMapping),
                               sampleAspectRatio: aspectRatio,
                               masteringDisplayColorVolume: masteringDisplayColorVolume,
                               contentLightLevel: contentLightLevel)
    }
}

/// Extension that adds conversion from/to arsdk enum.
extension VideoFormatRawPixelFormat: ArsdkMappableEnum {

    static let arsdkMapper = Mapper<VideoFormatRawPixelFormat, SdkCoreRawPixFormat>([
        .yuv420: .yuv420,
        .yuv422: .yuv422,
        .yuv444: .yuv444,
        .gray: .gray,
        .rgb24: .rgb24,
        .rgba32: .rgba32,
        .bayer: .bayer,
        .depth: .depth,
        .depthFloat: .depthFloat])
}

/// Extension that adds conversion from/to arsdk enum.
extension VideoFormatRawPixelOrder: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<VideoFormatRawPixelOrder, SdkCoreRawPixOrder>([
        .ABCD: .ABCD,
        .ABDC: .ABDC,
        .ACBD: .ACBD,
        .ACDB: .ACDB,
        .ADBC: .ADBC,
        .ADCB: .ADCB,

        .BACD: .BACD,
        .BADC: .BADC,
        .BCAD: .BCAD,
        .BCDA: .BCDA,
        .BDAC: .BDAC,
        .BDCA: .BDCA,

        .CABD: .CABD,
        .CADB: .CADB,
        .CBAD: .CBAD,
        .CBDA: .CBDA,
        .CDAB: .CDAB,
        .CDBA: .CDBA,

        .DABC: .DABC,
        .DACB: .DACB,
        .DBAC: .DBAC,
        .DBCA: .DBCA,
        .DCAB: .DCAB,
        .DCBA: .DCBA])
}

/// Extension that adds conversion from/to arsdk enum.
extension VideoFormatRawPixelLayout: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<VideoFormatRawPixelLayout, SdkCoreRawPixLayout>([
        .linear: .linear,
        .hiSiliconTile64X16: .hiSiTile64x16,
        .hiSiliconTile64X16Ccompressed: .hiSiTile64x16Compressed])
}

/// Extension that adds conversion from/to arsdk enum.
extension VideoFormatRawDataLayout: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<VideoFormatRawDataLayout, SdkCoreRawDataLayout>([
        .packed: .packed,
        .planar: .planar,
        .semiPlanar: .semiPlanar,
        .interleaved: .interleaved,
        .opaque: .opaque])
}

/// Extension that adds conversion from/to arsdk enum.
extension VideoFormatTransferFunction: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<VideoFormatTransferFunction, SdkCoreTransferFunction>([
        .bt601: .bt601,
        .bt709: .bt709,
        .bt2020: .bt2020,
        .pq: .pq,
        .hlg: .hlg,
        .srgb: .srgb])
}

/// Extension that adds conversion from/to arsdk enum.
extension VideoFormatMatrixCoefficients: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<VideoFormatMatrixCoefficients, SdkCoreMatrixCoefs>([
        .identity: .identity,
        .bt601x525: .bt601x525,
        .bt601x625: .bt601x625,
        .bt709: .bt709,
        .bt2020NonCst: .bt2020NonCst,
        .bt2020Cst: .bt2020Cst])
}

/// Extension that adds conversion from/to arsdk enum.
extension VideoFormatDynamicRange: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<VideoFormatDynamicRange, SdkCoreDynamicRange>([
        .sdr: .sdr,
        .hdr8: .hdr8,
        .hdr10: .hdr10])
}

/// Extension that adds conversion from/to arsdk enum.
extension VideoFormatToneMapping: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<VideoFormatToneMapping, SdkCoreToneMapping>([
        .standard: .standard,
        .pLog: .pLog])
}

/// Extension that adds conversion from/to arsdk enum.
extension VideoFormatColorPrimaries {
    static func fromArsdk(_ arsdkValue: SdkCoreColorPrimaries) -> VideoFormatColorPrimaries? {
        switch arsdkValue {
        case .bt601x525:
            return .bt601x525
        case .bt601x625:
            return .bt601x625
        case .bt709:
            return .bt709
        case .bt2020:
            return .bt2020
        case .dciP3:
            return .dciP3
        case .displayP3:
            return .displayP3
        default:
            return nil
        }
    }
}
