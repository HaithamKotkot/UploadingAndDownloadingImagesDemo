/// Copyright (c) 2021 Razeware LLC
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

import Foundation
import Alamofire

enum ImaggaRouter: URLRequestConvertible {
  enum Constants {
    static let naseURlPath = "https://api.imagga.com/v2"
  }
  
  case upload
  case tags(String)
  case colors(String)
  
  var method: HTTPMethod {
    switch self {
    case .upload:
      return .post
    case .tags, .colors:
      return .get
    }
  }
  
  var path: String {
    switch self {
    case .upload:
      return "/uploads"
    case .tags:
      return "/tags"
    case .colors:
      return "/colors"
    }
  }
  
  var paramters: [String: Any] {
    switch self {
    case .tags(let contentID):
      return ["image_upload_id": contentID]
    case .colors(let contentID):
      return ["image_upload_id": contentID, "extract_object_colors": 0]
    default:
      return [:]
    }
  }
  
  func asURLRequest() throws -> URLRequest {
    let url = try Constants.naseURlPath.asURL()
    var request = URLRequest(url: url.appendingPathComponent(path))
    request.method = method
    request.timeoutInterval = TimeInterval(10 * 1000)
    return try URLEncoding.default.encode(request, with: paramters)
  }
}
