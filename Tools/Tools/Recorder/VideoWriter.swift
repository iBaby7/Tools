//
//  VideoWriter.swift
//  Tools
//
//  Created by 杨名宇 on 2020/12/24.
//

import Foundation
import AVFoundation
import CoreImage
import UIKit

protocol VideoWriterDelegate: class {
    func writerDidFinishRecording(_ fileURL: URL,_ error: Error?)
}

class VideoWriter: NSObject {
    var videoSize: CGSize?
    weak var delegate: VideoWriterDelegate?
    
    private var writerQueue = DispatchQueue(label: "Record.Writer.Queue")
    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var videoSetting: [String: Any]?
    private var audioSetting: [String: Any]?
    private var inputPixelBufferAdptor: AVAssetWriterInputPixelBufferAdaptor?
    private var currentSampleTime: CMTime?
    private var currentVideoDimensions: CMVideoDimensions?
    private var context: CIContext?
    
    private var isStartWriting = false
    private var outputFileUrl: URL? {
        didSet {
            if outputFileUrl != nil {
                writerQueue.async { [weak self] in
                    guard let self = self else { return }
                    self.writer = try? AVAssetWriter(outputURL: self.outputFileUrl!, fileType: .mp4)
                    self.setupVideoInput()
                    self.setupAudioInput()
                    self.context = CIContext(options: nil)
                    self.fixVideoInputOrientation()
                    if self.writer!.canAdd(self.videoInput!) { self.writer!.add(self.videoInput!) }
                    if self.writer!.canAdd(self.audioInput!) { self.writer!.add(self.audioInput!) }
                }
            }
        }
    }
    
    override init() {
        super.init()
        videoSize = UIScreen.main.bounds.size
    }
    
    func startWriting(_ url: URL) {
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(atPath: url.path)
        }
        outputFileUrl = url
    }
    
    func writingVideo(_ sampleBuffer: CMSampleBuffer,_ connection: AVCaptureConnection,_ filterImage: CIImage? = nil) {
        if !isReady() { return }
//        writerQueue.async { [weak self] in
//            guard let self = self else { return }
            if filterImage != nil {
                autoreleasepool {
                    objc_sync_enter(self)
                    let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer)!
                    self.currentVideoDimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
                    self.currentSampleTime = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer)
                    self.setupInputPixelBufferAdptor()
                    if !self.isStartWriting {
                        self.writer?.startWriting()
                        self.writer?.startSession(atSourceTime: self.currentSampleTime!)
                        self.isStartWriting = true
                    }
                    if self.inputPixelBufferAdptor!.assetWriterInput.isReadyForMoreMediaData {
                        var newPixelBuffer: CVPixelBuffer? = nil
                        let status: CVReturn = CVPixelBufferCreate(nil, Int(self.currentVideoDimensions!.width), Int(self.currentVideoDimensions!.height), kCVPixelFormatType_32BGRA, nil, &newPixelBuffer)
                        if self.writer!.status == .writing, status == kCVReturnSuccess {
                            let isSuc = self.inputPixelBufferAdptor!.append(newPixelBuffer!, withPresentationTime: self.currentSampleTime!)
                            if !isSuc { self.finishWriting() }
                        }
                    }
                    objc_sync_exit(self)
                }
            }
            else {
//                autoreleasepool {
//                    objc_sync_enter(self)
                    if !self.isStartWriting {
                        self.writer!.startWriting()
                        self.writer!.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
                        self.isStartWriting = true
                    }
                    if self.videoInput!.isReadyForMoreMediaData, self.isStartWriting {
                        let isSuc = self.videoInput!.append(sampleBuffer)
                        if !isSuc { self.finishWriting() }
                    }
//                    objc_sync_exit(self)
//                }
            }
//        }
    }
    
    func writingAudio(_ sampleBuffer: CMSampleBuffer,_ connection: AVCaptureConnection) {
        return
        if !isReady() { return }
        writerQueue.async { [weak self] in
            guard let self = self else { return }
            autoreleasepool {
                objc_sync_enter(self)
                if !self.isStartWriting {
                    self.writer!.startWriting()
                    self.writer!.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
                    self.isStartWriting = true
                }
                if self.audioInput!.isReadyForMoreMediaData, self.isStartWriting {
                    let isSuc = self.audioInput!.append(sampleBuffer)
                    if !isSuc { self.finishWriting() }
                }
                objc_sync_exit(self)
            }
        }
    }
    
    func finishWriting() {
        writerQueue.async { [weak self] in
            guard let self = self else { return }
            objc_sync_enter(self)
            if self.writer != nil, self.isStartWriting, self.writer!.status != .unknown {
                self.writer!.finishWriting { [weak self] in
                    guard let self = self else { return }
                    DispatchQueue.main.async {
                        self.delegate?.writerDidFinishRecording(self.outputFileUrl!, self.writer!.error)
                    }
                    self.isStartWriting = false
                    self.inputPixelBufferAdptor = nil
                    self.context = nil
                    self.writer = nil
                    self.videoInput = nil
                    self.audioInput = nil
                }
            }
            objc_sync_exit(self)
        }
    }
}

// Setup
extension VideoWriter {
    private func setupVideoInput() {
        let width = self.videoSize!.width * UIScreen.main.scale
        let height = self.videoSize!.height * UIScreen.main.scale
        let numPixels = width * height
        let bitsPerPixel: CGFloat = 24.0
        let bitsPerSecond = numPixels * bitsPerPixel
        let compressionProperties = [AVVideoAverageBitRateKey: bitsPerSecond,
                                     AVVideoExpectedSourceFrameRateKey: 15,
                                     AVVideoMaxKeyFrameIntervalKey:15,
                                     AVVideoProfileLevelKey:AVVideoProfileLevelH264High40] as [String : Any]
        videoSetting = [AVVideoCodecKey: AVVideoCodecType.h264,
                        AVVideoWidthKey:width,
                        AVVideoHeightKey:height,
                        AVVideoScalingModeKey:AVVideoScalingModeResizeAspectFill,
                        AVVideoCompressionPropertiesKey:compressionProperties]
        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSetting)
        videoInput?.expectsMediaDataInRealTime = true
    }
    
    private func setupAudioInput() {
        audioSetting = [AVEncoderBitRatePerChannelKey: 28000,
                        AVFormatIDKey:kAudioFormatMPEG4AAC,
                        AVNumberOfChannelsKey:1,
                        AVSampleRateKey:22050]
        audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSetting)
    }
    
    private func setupInputPixelBufferAdptor() {
        if inputPixelBufferAdptor != nil { return }
        let sourcePixelBufferAttributes = [String(kCVPixelBufferPixelFormatTypeKey): kCVPixelFormatType_32BGRA,
                                           String(kCVPixelBufferWidthKey):currentVideoDimensions!.width,
                                           String(kCVPixelBufferHeightKey):currentVideoDimensions!.height,
                                           String(kCVPixelFormatOpenGLESCompatibility):1] as [String : Any]
        inputPixelBufferAdptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput!, sourcePixelBufferAttributes: sourcePixelBufferAttributes)
    }
}

// Tools
extension VideoWriter {
    private func fixVideoInputOrientation() {
        switch UIDevice.current.orientation {
        case .landscapeRight:
            videoInput?.transform = CGAffineTransform(rotationAngle: CGFloat.pi/2.0)
        case .landscapeLeft:
            videoInput?.transform = CGAffineTransform(rotationAngle: -CGFloat.pi/2.0)
        case .portraitUpsideDown:
            videoInput?.transform = CGAffineTransform(rotationAngle: CGFloat.pi)
        default:
            videoInput?.transform = CGAffineTransform(rotationAngle: 0)
        }
    }
    
    private func isReady() -> Bool {
        return writer != nil && videoInput != nil && audioInput != nil
    }
}
