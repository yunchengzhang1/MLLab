//
//  ViewController.swift
//  HTTPSwiftExample
//
//  Created by Eric Larson on 3/30/15.
//  Copyright (c) 2015 Eric Larson. All rights reserved.
//

// This exampe is meant to be run with the python example:
//              tornado_turiexamples.py 
//              from the course GitHub repository: tornado_bare, branch sklearn_example


// if you do not know your local sharing server name try:
//    ifconfig |grep "inet "
// to see what your public facing IP address is, the ip address can be used here

// CHANGE THIS TO THE URL FOR YOUR LAPTOP
let SERVER_URL = "http://192.168.1.217:8000" // change this for your server name!!!

import UIKit
import CoreMotion

extension UIImage {
    func pixelData() -> [Double]? {
        let size = self.size
        let dataSize = size.width * size.height * 4
        var pixelData = [Double](repeating: 0, count: Int(dataSize))
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: &pixelData,
                                width: Int(size.width),
                                height: Int(size.height),
                                bitsPerComponent: 8,
                                bytesPerRow: 4 * Int(size.width),
                                space: colorSpace,
                                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        guard let cgImage = self.cgImage else { return nil }
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
//
//        if (pixelData != nil){
//            return pixelData
//        }
        return pixelData
    }
 }

class ViewController: UIViewController, UIImagePickerControllerDelegate, URLSessionDelegate, UINavigationControllerDelegate {
    
    // MARK: Class Properties
    lazy var session: URLSession = {
        let sessionConfig = URLSessionConfiguration.ephemeral
        
        sessionConfig.timeoutIntervalForRequest = 5.0
        sessionConfig.timeoutIntervalForResource = 8.0
        sessionConfig.httpMaximumConnectionsPerHost = 1
        
        return URLSession(configuration: sessionConfig,
                          delegate: self,
                          delegateQueue:self.operationQueue)
    }()
    
    let operationQueue = OperationQueue()
    let motionOperationQueue = OperationQueue()
    let calibrationOperationQueue = OperationQueue()
    
    var ringBuffer = RingBuffer()
    
    @IBOutlet weak var dsidLabel: UILabel!
    @IBAction func dsidChanged(_ sender: UISlider) {
        self.dsid = Int(sender.value)
    }
    
    var dsid:Int = 0 {
        didSet{
            DispatchQueue.main.async{
                // update label when set
              
                self.dsidLabel.text = "Current DSID: \(self.dsid)"
            }
        }
    }
    
    // MARK: View Controller Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        dsid = 50 // set this and it will update UI
    }
    
    
    @IBOutlet weak var imageView: UIImageView!
    
    @IBAction func uploadOpenHand(_ sender: UIButton) {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .camera
        self.present(picker, animated: true, completion: nil)
        print("uploadOpenHand button clicked")
    }
    
    //user canceled, do nothing
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.dismiss(animated: true, completion: nil)
    }
    //where we send image
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        let info = convertFromUIImagePickerControllerInfoKeyDictionary(info)
        self.dismiss(animated: true, completion: nil)
        
        let image = info["UIImagePickerControllerOriginalImage"] as? UIImage
//        sendFeatures((image?.pixelData())!, withLabel: "test")
//        let cropRect = CGRect(x: 0, y: 0, width: image?.size.width/2, height: image?.size.height/2).integral
        
        let imageData: Data = image?.jpegData(compressionQuality: 0.1) ?? Data()
        let imagestr: String = imageData.base64EncodedString()
        
//        print(imagestr)
        if (imagestr != nil){
            sendFeatures(imagestr, withLabel: "open")
        } else{
            print("imagestr is nil")
        }
        
        
        
        //image.base64EncodedString()
        //convert into cgImage to access the pixels
//        guard let cgImage = image?.cgImage, //might throw an error
//              let data = cgImage.dataProvider?.data,
//              let bytes = CFDataGetBytePtr(data) else{ //error handling
//            fatalError("Could not access image data")
//        }
//        assert(cgImage.colorSpace?.model == .rgb)
//        let bytesPerPixel = cgImage.bitsPerPixel / cgImage.bitsPerComponent
//        for y in 0 ..< cgImage.height{
//            for x in 0 ..< cgImage.width {
//                let offset = (y * cgImage.bytesPerRow) + (x * bytesPerPixel)
//                let grey = generateGreyScale(R: Float(bytes[offset]), G: Float(bytes[offset+1]), B: Float(bytes[offset+2]))
                
                //print("[x:\(x), y:\(y)] grey: \(grey)")
                //uncomment below to test with printout
//                let components = (r: bytes[offset], g:bytes[offset+1], b:bytes[offset+2])
//                print("[x:\(x), y:\(y)] \(components)")
//            }
//        }
        DispatchQueue.main.async {
            self.imageView.image = image
        }
    }
//    func getGrayScale(img: UIImage ,width: Int, height: Int) -> UIImage{
//        let image = CGRect(x: 0, y: 0, width: width, height: height)
//        let colorSpace = CGColorSpaceCreateDeviceGray()
//        let context = CGContext(data: nil, width: Int(width), height: Int(height), bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue).rawValue)
//        context?.draw(self.cgImage!, in: image)
//        let imageReference = context!.makeImage()
//        let newImage = UIImage(cgImage: imageReference!)
//        return newImage
//    }
    
    
    
    func generateGreyScale(R: Float, G: Float, B: Float) -> Float{
        return (R + G + B)/3
    }
    
    fileprivate func convertFromUIImagePickerControllerInfoKeyDictionary(_ input: [UIImagePickerController.InfoKey: Any]) -> [String: Any]{
        return Dictionary(uniqueKeysWithValues: input.map {key, value in (key.rawValue, value)})
    }
    
    //MARK: Comm with Server
    func sendFeatures(_ encoding:String, withLabel label:NSString){
        let baseURL = "\(SERVER_URL)/AddDataPoint"
        let postUrl = URL(string: "\(baseURL)")
        
        // create a custom HTTP POST request
        var request = URLRequest(url: postUrl!)
        
        // data to send in body of post request (send arguments as json)
        let jsonUpload:NSDictionary = ["feature":encoding,
                                       "label":"\(label)",
                                       "dsid":self.dsid]
        
        let requestBody:Data? = self.convertDictionaryToData(with:jsonUpload)
        
        request.httpMethod = "POST"
        request.httpBody = requestBody
        
        let postTask : URLSessionDataTask = self.session.dataTask(with: request,
                                                                  completionHandler:{(data, response, error) in
            if(error != nil){
                if let res = response{
                    print("Response:\n",res)
                }
            }
            else{
                let jsonDictionary = self.convertDataToDictionary(with: data)
                if (jsonDictionary["feature"] == nil){
                    print("jsondic is nil")
                }else{
                    print("jsondic not nil")
                }
                if let feature = jsonDictionary["feature"]{
                    print(feature)

                }else{
                    print("feature is nil")
                }
                if let label = jsonDictionary["label"]{
                    print(label)

                }else{
                    print("label is nil")
                }
            }
            
        })
        
        postTask.resume() // start the task
    }
    
    func getPrediction(_ array:[Double]){
        let baseURL = "\(SERVER_URL)/PredictOne"
        let postUrl = URL(string: "\(baseURL)")
        
        // create a custom HTTP POST request
        var request = URLRequest(url: postUrl!)
        
        // data to send in body of post request (send arguments as json)
        let jsonUpload:NSDictionary = ["feature":array, "dsid":self.dsid]
        
        
        let requestBody:Data? = self.convertDictionaryToData(with:jsonUpload)
        
        request.httpMethod = "POST"
        request.httpBody = requestBody
        
        let postTask : URLSessionDataTask = self.session.dataTask(with: request,
                                                                  completionHandler:{
            (data, response, error) in
            if(error != nil){
                if let res = response{
                    print("Response:\n",res)
                }
            }
            else{ // no error we are aware of
                let jsonDictionary = self.convertDataToDictionary(with: data)
                
                let labelResponse = jsonDictionary["prediction"]!
                print(labelResponse)
                self.displayLabelResponse(labelResponse as! String)
                
            }
            
        })
        
        postTask.resume() // start the task
    }
    
    func displayLabelResponse(_ response:String){
        switch response {
        case "['open']":
            print("hi")
            break
        case "['fist']":
            print("hi")
            break
        default:
            print("Unknown")
            break
        }
    }
    
    
    
    @IBAction func makeModel(_ sender: AnyObject) {
        
        // create a GET request for server to update the ML model with current data
        let baseURL = "\(SERVER_URL)/UpdateModel"
        let query = "?dsid=\(self.dsid)"
        
        let getUrl = URL(string: baseURL+query)
        let request: URLRequest = URLRequest(url: getUrl!)
        let dataTask : URLSessionDataTask = self.session.dataTask(with: request,
                                                                  completionHandler:{(data, response, error) in
            // handle error!
            if (error != nil) {
                if let res = response{
                    print("Response:\n",res)
                }
            }
            else{
                let jsonDictionary = self.convertDataToDictionary(with: data)
                
                if let resubAcc = jsonDictionary["resubAccuracy"]{
                    print("Resubstitution Accuracy is", resubAcc)
                }
            }
            
        })
        
        dataTask.resume() // start the task
        
    }
    
    //MARK: JSON Conversion Functions
    func convertDictionaryToData(with jsonUpload:NSDictionary) -> Data?{
        do { // try to make JSON and deal with errors using do/catch block
            let requestBody = try JSONSerialization.data(withJSONObject: jsonUpload, options:JSONSerialization.WritingOptions.prettyPrinted)
            return requestBody
        } catch {
            print("json error: \(error.localizedDescription)")
            return nil
        }
    }
    
    func convertDataToDictionary(with data:Data?)->NSDictionary{
        do { // try to parse JSON and deal with errors using do/catch block
            let jsonDictionary: NSDictionary =
            try JSONSerialization.jsonObject(with: data!,
                                             options: JSONSerialization.ReadingOptions.mutableContainers) as! NSDictionary
            
            return jsonDictionary
            
        } catch {
            
            if let strData = String(data:data!, encoding:String.Encoding(rawValue: String.Encoding.utf8.rawValue)){
                print("printing JSON received as string: "+strData)
            }else{
                print("json error: \(error.localizedDescription)")
            }
            return NSDictionary() // just return empty
        }
    }
    
}





