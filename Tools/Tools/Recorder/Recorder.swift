//
//  Recorder.swift
//  Tools
//
//  Created by 杨名宇 on 2020/12/24.
//

import Foundation
import AVFoundation
import CoreImage
import UIKit

protocol RecorderDelegate: class {
    func recoderDidStartRecording(_ recorder: Recorder)
    func recoderDidFinishRecording(_ recorder: Recorder,_ url: URL)
}

class Recorder: NSObject {
    weak var delegate: RecorderDelegate?
    var previewLayer: CALayer = CALayer()
    var filter: CIFilter?
    
    private var session: AVCaptureSession?
    private var writer: VideoWriter?
    private var device: AVCaptureDevice?
    private var sessionQueue = DispatchQueue(label: "Record.Session.Queue")
    private var videoOutput: AVCaptureVideoDataOutput?
    private var audioOutput: AVCaptureAudioDataOutput?
    
    private var lastCameraImage: CIImage?
    private var lastFilterImage: CIImage?
    private var filterContext: CIContext?
    
    private var isRecording: Bool = false
    
    
    override init() {
        super.init()
        session = setupCaptureSession()
        
        videoOutput = AVCaptureVideoDataOutput()
        videoOutput?.setSampleBufferDelegate(self, queue: sessionQueue)
        addOutput(videoOutput!, session!)
        
        audioOutput = AVCaptureAudioDataOutput()
        audioOutput?.setSampleBufferDelegate(self, queue: sessionQueue)
        addOutput(audioOutput!, session!)
        
        filterContext = CIContext()
        
        writer = VideoWriter()
        writer!.delegate = self
    }
    
    func setDelegate(_ delegate: RecorderDelegate) {
        objc_sync_enter(self)
        self.delegate = delegate
        objc_sync_exit(self)
    }
    
    func startRunning() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.session?.startRunning()
        }
    }
    
    func stopRunning() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.session?.stopRunning()
        }
    }
    
    func startRecording() {
        let url = tempFileUrl()
        writer?.startWriting(url)
        isRecording = true
        DispatchQueue.main.async {
            self.delegate?.recoderDidStartRecording(self)
        }
    }
    
    func stopRecording() {
        writer?.finishWriting()
        isRecording = false
    }
    
}

// WriterDelegate
extension Recorder: VideoWriterDelegate {
    func writerDidFinishRecording(_ fileURL: URL, _ error: Error?) {
//        stopRunning()
        print("record finished")
        DispatchQueue.main.async {
            self.delegate?.recoderDidFinishRecording(self, fileURL)
        }
    }
}

// Video&AudioDelegate
extension Recorder: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if output == videoOutput {
            let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
            lastCameraImage = CIImage(cvPixelBuffer: imageBuffer)
            if filter != nil {
                filter!.setValue(lastCameraImage, forKey: kCIInputImageKey)
                lastFilterImage = filter!.outputImage!
            }
            else {
                lastFilterImage = lastCameraImage
            }
            fixImageOrientation()
            let cgImage = filterContext?.createCGImage(lastFilterImage!, from: lastFilterImage!.extent)
            DispatchQueue.main.async {
                self.previewLayer.contents = cgImage
            }
            if isRecording {
                writer?.writingVideo(sampleBuffer, connection, filter == nil ? nil : lastFilterImage)
            }
            autoreleasepool {
                
            }
        }
        if output == audioOutput {
            if isRecording {
                writer?.writingAudio(sampleBuffer, connection)
            }
        }
    }
}

// Setup
extension Recorder {
    @discardableResult
    func addInput(_ input: AVCaptureDeviceInput,_ captureSession: AVCaptureSession) -> Bool {
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
            return true
        }
        return false
    }
    
    @discardableResult
    func addOutput(_ output: AVCaptureOutput,_ captureSession: AVCaptureSession) -> Bool {
        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
            return true
        }
        return false
    }
    private func setupCaptureSession() -> AVCaptureSession {
        let session = AVCaptureSession()
        if !addDefaultCameraInput(session) { print("no camera") }
        if !addDefaultMicInput(session) { print("no mic") }
        return session
    }
    private func addDefaultCameraInput(_ captureSession: AVCaptureSession) -> Bool {
        do {
            let cameraInput = try AVCaptureDeviceInput(device: AVCaptureDevice.default(for: .video)!)
            return addInput(cameraInput, captureSession)
        } catch {
            return false
        }
    }
    private func addDefaultMicInput(_ captureSession: AVCaptureSession) -> Bool {
        do {
            let micInput = try AVCaptureDeviceInput(device: AVCaptureDevice.default(for: .audio)!)
            return addInput(micInput, captureSession)
        } catch {
            return false
        }
    }
}

// Tools
extension Recorder {
    private func tempFileUrl() -> URL {
        let cachePath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!
        var path: String = ""
        let fm = FileManager.default
        var i: Int = 0
        while path.isEmpty || fm.fileExists(atPath: path) {
            path = cachePath + "/output\(i.description).mp4"
            i += 1
        }
        return URL(fileURLWithPath: path)
    }
    
    private func fixImageOrientation() {
        switch UIDevice.current.orientation {
        case .landscapeRight:
            lastFilterImage = lastFilterImage?.transformed(by: CGAffineTransform(rotationAngle: CGFloat.pi))
        case .portraitUpsideDown:
            lastFilterImage = lastFilterImage?.transformed(by: CGAffineTransform(rotationAngle: CGFloat.pi/2.0))
        case .portrait:
            lastFilterImage = lastFilterImage?.transformed(by: CGAffineTransform(rotationAngle: -CGFloat.pi/2.0))
        case .landscapeLeft:
            lastFilterImage = lastFilterImage?.transformed(by: CGAffineTransform(rotationAngle: 0))
        default:
            lastFilterImage = lastFilterImage?.transformed(by: CGAffineTransform(rotationAngle: -CGFloat.pi/2.0))
        }
    }
}
