//
//  ViewController.swift
//  Tools
//
//  Created by 杨名宇 on 2020/12/23.
//

import UIKit

class ViewController: UIViewController {
    
    @IBOutlet weak var recordBtn: UIButton!
    
    var recorder: Recorder?
    
    private var isRecording = false

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        recorder = Recorder()
//        recorder?.filter = CIFilter(name: "CIMotionBlur")
        recorder!.previewLayer.frame = view.bounds
        view.layer.insertSublayer(recorder!.previewLayer, at: 0)
        
        recorder?.startRunning()
        recorder?.delegate = self
    }
    
    @IBAction func record(_ sender: Any) {
        if !isRecording {
            recorder?.startRecording()
            recordBtn.isEnabled = false
            recordBtn.setTitle("stop", for: .normal)
        }
        else {
            recorder?.stopRecording()
        }
    }
}

extension ViewController: RecorderDelegate {
    func recoderDidStartRecording(_ recorder: Recorder) {
        print("start")
        recordBtn.isEnabled = true
    }
    
    func recoderDidFinishRecording(_ recorder: Recorder,_ url: URL) {
        isRecording = false
        print(url)
        recordBtn.setTitle("record", for: .normal)
    }
    
    
}
