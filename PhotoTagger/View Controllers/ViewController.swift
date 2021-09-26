/// Copyright (c) 2018 Razeware LLC
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import UIKit
import Alamofire

class ViewController: UIViewController {
  
  // MARK: - IBOutlets
  @IBOutlet var takePictureButton: UIButton!
  @IBOutlet var imageView: UIImageView!
  @IBOutlet var progressView: UIProgressView!
  @IBOutlet var activityIndicatorView: UIActivityIndicatorView!
  @IBOutlet weak var downloadSampleImageButton: UIButton!
  
  
  // MARK: - Properties
  private var tags: [String]?
  private var colors: [PhotoColor]?
  
  // MARK: - View Life Cycle
  override func viewDidLoad() {
    super.viewDidLoad()
    
    if !UIImagePickerController.isSourceTypeAvailable(.camera) {
      takePictureButton.setTitle("Select Photo", for: .normal)
    }
  }
  
  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    
    imageView.image = nil
  }
  
  // MARK: - Navigation
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    
    
    if segue.identifier == "ShowResults",
      let controller = segue.destination as? TagsColorsViewController {
      controller.tags = tags
      controller.colors = colors
    }
  }
  
  // MARK: - IBActions
  @IBAction func takePicture(_ sender: UIButton) {
    let picker = UIImagePickerController()
    picker.delegate = self
    picker.allowsEditing = false
    
    if UIImagePickerController.isSourceTypeAvailable(.camera) {
      picker.sourceType = .camera
    } else {
      picker.sourceType = .photoLibrary
      picker.modalPresentationStyle = .fullScreen
    }
    
    present(picker, animated: true)
  }
  
  @IBAction func downloadSampleImage(_ sender: UIButton) {
    takePictureButton.isHidden = true
    downloadSampleImageButton.isHidden = true
    progressView.progress = 0.0
    progressView.isHidden = false
    activityIndicatorView.startAnimating()
    downloadSampleImage { [unowned self] progress in
      self.progressView.setProgress(progress, animated: true)
    } completion: { [unowned self] tags, colors in
      self.takePictureButton.isHidden = false
      self.downloadSampleImageButton.isHidden = false
      self.progressView.isHidden = true
      self.activityIndicatorView.stopAnimating()
      self.tags = tags
      self.colors = colors
      self.performSegue(withIdentifier: "ShowResults", sender: self)
    }
  }
}

// MARK: - UIImagePickerControllerDelegate
extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
  
  func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any])
  {
    guard let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage else {
      print("Info did not have the required UIImage for the Original Image")
      dismiss(animated: true)
      return
    }
    
    imageView.image = image
    
    takePictureButton.isHidden = true
    downloadSampleImageButton.isHidden = true
    progressView.progress = 0.0
    progressView.isHidden = false
    activityIndicatorView.startAnimating()
    
    upload(image: image,
           progressCompletion: { [unowned self] percent in
            self.progressView.setProgress(percent, animated: true)
      },
           completion: { [unowned self] tags, colors in
            self.takePictureButton.isHidden = false
            self.downloadSampleImageButton.isHidden = false
            self.progressView.isHidden = true
            self.activityIndicatorView.stopAnimating()
            
            self.tags = tags
            self.colors = colors
            
            self.performSegue(withIdentifier: "ShowResults", sender: self)
    })
    
    dismiss(animated: true)
  }
}

// MARK: - Networking calls
extension ViewController {
  func upload(image: UIImage,
              progressCompletion: @escaping (_ percent: Float) -> Void,
              completion: @escaping (_ tags: [String]?, _ colors: [PhotoColor]?) -> Void) {
    guard let imageData = image.jpegData(compressionQuality: 0.5) else {
      print("Could not get JPEG representation of UIImage")
      return
    }
    AF.upload(multipartFormData: { multiPartFormData in
      multiPartFormData.append(imageData, withName: "image", fileName: "image.jpg", mimeType: "image/jpeg")
    }, to: "https://api.imagga.com/v2/uploads").authenticate(username: ImaggaCredentials.username, password: ImaggaCredentials.password).validate().uploadProgress { progress in
      progressCompletion(Float(progress.fractionCompleted))
    }.responseDecodable(of: UploadImageResponse.self) { response in
      switch response.result {
      case .failure(let error):
        print("Error uploading file: \(error)")
        completion(nil, nil)
      case .success(let uploadResponse):
        let resultID = uploadResponse.result.uploadID
        print("Constant upload with ID: \(resultID)")
        self.downloadTags(contentID: resultID) { tags in
          self.downloadColors(contentID: resultID) { colors in
            completion(tags, colors)
          }
        }
      }
    }
  }
  
  func downloadTags(contentID: String, completion: @escaping ([String]?) -> Void) {
    let params = ["image_upload_id": contentID]
    AF.request("https://api.imagga.com/v2/tags", parameters: params).authenticate(username: ImaggaCredentials.username, password: ImaggaCredentials.password).validate().responseDecodable(of: PhotoTagsResponse.self) { response in
      switch response.result {
      case .failure(let error):
        print("Error while fetching tags: \(String(describing: error))")
      case .success(let tagsResponse):
        let tags = tagsResponse.result.tags.map { $0.tag.en }
        completion(tags)
      }
    }
  }
  
  func downloadColors(contentID: String, completion: @escaping ([PhotoColor]?) -> Void) {
    let params = ["image_upload_id": contentID, "extract_obejct_colors": 0] as [String : Any]
    AF.request("https://api.imagga.com/v2/colors", parameters: params).authenticate(username: ImaggaCredentials.username, password: ImaggaCredentials.password).validate().responseDecodable(of: PhotoColorsResponse.self) { response in
      switch response.result {
      case .failure(let error):
        print("Error while fetching colors: \(String(describing: error))")
      case .success(let tagsResponse):
        let colors = tagsResponse.result.colors.imageColors.map { PhotoColor(red: $0.red, green: $0.green, blue: $0.blue, colorName: $0.closestPaletteColor) }
        completion(colors)
      }
    }
  }
  
  func downloadSampleImage(progressCompletion: @escaping (_ percent: Float) -> Void, completion: @escaping (_ tags: [String]?, _ colors: [PhotoColor]?) -> Void) {
    let imageURL = "https://upload.wikimedia.org/wikipedia/commons/thumb/b/b3/Wikipedia-logo-v2-en.svg/1200px-Wikipedia-logo-v2-en.svg.png"
    AF.download(imageURL).validate().downloadProgress { progress in
      progressCompletion(Float(progress.fractionCompleted))
    }.responseData { response in
      switch response.result {
      case .failure(let error):
        print("Error while fetching the imagga: \(String(describing: error))")
        completion(nil, nil)
      case .success(let imageData):
        guard let image = UIImage(data: imageData) else {
          print("Error while converting the image data to a UIImage")
          completion(nil, nil)
          return
        }
        self.upload(image: image, progressCompletion: progressCompletion) { tags, colors in
          completion(tags, colors)
        }
      }
    }
  }
}
