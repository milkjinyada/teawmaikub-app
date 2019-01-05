//
//  SetupProfile.swift
//  Teawmaikub
//
//  Created by jinyada on 10/4/60.
//  Copyright © พ.ศ. 2560 jinyada. All rights reserved.
//

import UIKit
import AVFoundation
import Firebase
import FirebaseDatabase
import FirebaseStorage

class SetupProfile: UIViewController, AVCapturePhotoCaptureDelegate {
    
    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var captureImage: UIImageView!
    @IBOutlet weak var displayNameTextField: UITextField!
    var captureSession = AVCaptureSession() //ตั้งตัวแปร session
    var capturePhotoOutput = AVCapturePhotoOutput() //ไว้เก็บภาพ
    var previewLayar = AVCaptureVideoPreviewLayer() //แสดง preview

    override func viewDidLoad() {
        super.viewDidLoad()
        
//ดึงรูปโปรไฟล์
        
        let uid = FIRAuth.auth()?.currentUser?.uid // ดึงค่า UID ของ user ที่ใช้งานไปเก็บไว้ใน uid
        let databaseRef = FIRDatabase.database().reference() //บอกว่าต้องไปดึงข้อมูลมาจากรูทไหน
        //โฟลเดอร์ไหน
        databaseRef.child("User/\(uid!)").observeSingleEvent(of: .value, with: { (firDataSnapshot) in
            //เช็คดูว่ามี user นี้เคยอัพรูปโปรไฟล์ไหม
            //เพราะข้อมูลมันเป็นแบบ dictionnary เลยต้องแคสออกมาให้type เดียวกัน
            if let userValue = firDataSnapshot.value as? Dictionary<String,AnyObject>
            {
                if let displayName = userValue["DisplayName"] as? String
                {
                    self.displayNameTextField.text=displayName
                }
                //ดึงรูปออกมา
                if let userImageURL = userValue["UserImage"] as? String
                {
                    do
                    {
                        //ใส่ใน imageData
                        let imageData = try Data(contentsOf: URL(string: userImageURL)!)
                        self.captureImage.image = UIImage(data: imageData)
                    }
                    catch let error as NSError
                    {
                        print(error.localizedDescription)
                    }
                }

            }
        })
        
        
        let deviceDiscoverySession = AVCaptureDeviceDiscoverySession(deviceTypes: [AVCaptureDeviceType.builtInDualCamera,AVCaptureDeviceType.builtInTelephotoCamera,AVCaptureDeviceType.builtInWideAngleCamera], mediaType: AVMediaTypeVideo, position:AVCaptureDevicePosition.unspecified) //ตั้งค่ากล้องว่าจะเอาอะไรบ้าง กล้องหน้า โฟกัส
        
        //วนลูป device ทั้งหมด
        for device in (deviceDiscoverySession?.devices)!
        {
            //ถ้าเป็นกล้องหลัง
            if (device.position == AVCaptureDevicePosition.back
                
                )
            {
                do{
                    let input = try AVCaptureDeviceInput(device: device)
                    if (captureSession.canAddInput(input)) //ถ้าใส่ได้
                    {
                        captureSession.addInput(input) //ก็ใส่เข้าไป
                        
                        if (captureSession.canAddOutput(capturePhotoOutput))
                        {
                            captureSession.addOutput(capturePhotoOutput)
                            
                            previewLayar = AVCaptureVideoPreviewLayer(session: captureSession)
                            previewLayar.videoGravity = AVLayerVideoGravityResizeAspect //ตั้งค่าขนาด คงที่
                            previewLayar.connection.videoOrientation = AVCaptureVideoOrientation.portrait //ตั้งค่าให้เป็นแนวตั้ง
                            previewLayar.frame = previewView.bounds
                            previewView.layer.addSublayer(previewLayar)
                            captureSession.startRunning()//ให้เริ่มทำงาน
                        }
                    }
                    
                }
                catch
                {
                    print("ERROR")
                }
            }
    
        }
       
    }
    
//func  ปุ่ม capture
    @IBAction func capturePhotoClicked(_ sender:Any)
    {
        let capturePhotoSettings = AVCapturePhotoSettings()
        let previewPhotoPixelFormatType = capturePhotoSettings.availablePreviewPhotoPixelFormatTypes.first!//เซต format ให้รูป
        let previewPhotoPixelFormat = [kCVPixelBufferPixelFormatTypeKey as String: previewPhotoPixelFormatType,kCVPixelBufferWidthKey as String: 160,kCVPixelBufferHeightKey as String:160]//เซตบัฟเฟ่อ ความกว้าง ความสูง
        capturePhotoSettings.previewPhotoFormat = previewPhotoPixelFormat //ตั้งค่า format ลงไป
        
        capturePhotoOutput.capturePhoto(with: capturePhotoSettings, delegate: self) //ใส่ที่เราตั้งค่าไว้
    }
    
    //หลังจากกดปุ่มถ่ายแล้วรูปจะออกมาจากฟังก์ชั่นนี้  เราใช้ฟังก์ชันนี้ในการ preview
    
    func capture(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingPhotoSampleBuffer photoSampleBuffer: CMSampleBuffer?, previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        
        //ถ้า error
        if let error = error
        {
            print("Error: \(error.localizedDescription)")
        }
        
        // ถ้าไม่ error
        if let sampleBuffer = photoSampleBuffer,
            let previewSampleBuffer = previewPhotoSampleBuffer,
            let dataImage = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: sampleBuffer, previewPhotoSampleBuffer: previewSampleBuffer)
        {
            print(UIImage(data: dataImage)?.size as Any)//เช็ค
            
            let dataProvider = CGDataProvider(data: dataImage as CFData)
            let cgImageRef:CGImage! = CGImage(jpegDataProviderSource: dataProvider!, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
            
            //ได้รูปมา
            let image = UIImage(cgImage: cgImageRef, scale: 1.0, orientation: UIImageOrientation.leftMirrored)
            self.captureImage.image=image
        }
    }
    
//  func ปุ่ม save ภาพ
    
    @IBAction func saveClicked(_ sender:Any)
    {
        //เช็คก่อนว่าต้องมีภาพ
        if (captureImage.image != nil && displayNameTextField.text != ""){
      
            let uid = FIRAuth.auth()?.currentUser?.uid//เอายูนิกไอดีของแต่ละ user ที่ login ออกมา ของใครของมันไม่ซ้ำกัน
            //แปลง image ให้เป็น data
            if let UserImageData = UIImageJPEGRepresentation(captureImage.image!, 0.5) //0.5 คือขนาดไฟล์
            {
                let PhotoName = "\(uid).jpg"//ตั้งชื่อไฟล์
            //อัพลง storage
                let storageRef = UserImageStorageRef.child(PhotoName)
                storageRef.put(UserImageData, metadata: nil, completion: { (firStorageMetadata, error) in
                    if error != nil{
                        let ErrorMessage = "Error uploading photo:\(error?.localizedDescription)"
                        print(ErrorMessage)
                        Const().ShowAlert(title: "Error!!!", message: ErrorMessage, viewContronller: self)
                    }
                    else{ //  ถ้าไม่ error แสดงว่าอัพโหลดสำเร็จ
                        let downloadURL = firStorageMetadata?.downloadURL() //เก็บ url
                        let displayName = self.displayNameTextField.text //เก็บชื่อ
                        let userValue: Dictionary<String,AnyObject> = //จะใส่อะไรไปใน firebase ให้ใส่ในนี้ เป็นแบบ dic
                        [
                            //จะส่งเข้าไป 3 อย่าง  ยูนิไอดี displayname url
                            "UID": uid! as AnyObject,
                            "DisplayName": displayName! as AnyObject,
                            "UserImage": downloadURL?.absoluteString as AnyObject //เอาไว้เก็บว่ามันอัพภาพขึ้นไปใน url
                        ]
                        
                        let databaseRef = FIRDatabase.database().reference()
                        databaseRef.child("User/\(uid!)").updateChildValues(userValue) // save ไปที่โฟลเดอร์ User อยู่ใน uid ของแต่ละคน แล้วก็อัพเดตส่ง userValue ไป
                        
                        Const().ShowAlert(title: "Succeed", message: "", viewContronller: self)
                    }
                })
            }
        }
        else{
       
            Const().ShowAlert(title: "Error!!!", message: "กรุณาใส่รูปและระบุข้อมูล", viewContronller: self)
        }
    }

//ฟังก์ชั่นดึงตัว mainStorage ออกมา
    var mainStorageRef: FIRStorageReference
    {
        return FIRStorage.storage().reference(forURL:"gs://teawmaikub.appspot.com")
    }
    
//ตั้งชื่อโฟลลเดอร์
    var UserImageStorageRef: FIRStorageReference
    {
        return mainStorageRef.child("UserImage")
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    //hide keyboard when user touches outside keyborad
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        self.view.endEditing(true)
    }
    //presses reture key
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        textField.resignFirstResponder()
        
        return(true)
    }

    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
