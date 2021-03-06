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

struct NetworkClient {
  
  struct NetworkClientRetrier: RequestInterceptor {
    func retry(_ request: Request, for session: Session, dueTo error: Error, completion: @escaping (RetryResult) -> Void) {
      //Check that we got 403 error, which is the error the API returns when we have sent too many requests a second
      if let response = request.task?.response as? HTTPURLResponse, response.statusCode == 403 {
        completion(.retryWithDelay(1))
      } else {
        completion(.doNotRetryWithError(error))
      }
    }
  }
  
  struct Certificates {
    
    static let imagga = Certificates.certificate(filename: "imagga.com")
    static let wikimedia = Certificates.certificate(filename: "wikimedia.org")
    
    private static func certificate(filename: String) -> SecCertificate {
      let filepath = Bundle.main.path(forResource: filename, ofType: "der")!
      let data = try! Data(contentsOf: URL(fileURLWithPath: filepath))
      return SecCertificateCreateWithData(nil, data as CFData)!
    }
  }
  
  static let shared = NetworkClient()
  let session: Session
  let retrier: NetworkClientRetrier
  
  let evaluators = [
    "api.imagga.com": PinnedCertificatesTrustEvaluator(certificates: [Certificates.imagga]),
    "upload.wikimedia.org": PinnedCertificatesTrustEvaluator(certificates: [Certificates.wikimedia])
  ]
  
  init() {
    retrier = NetworkClientRetrier()
    self.session = Session(interceptor: retrier, serverTrustManager: ServerTrustManager(evaluators: evaluators))
  }
  
  static func request(_ convertable: URLRequestConvertible) -> DataRequest {
    shared.session.request(convertable).validate().authenticate(username: ImaggaCredentials.username, password: ImaggaCredentials.password)
  }
  
  static func download(_ url: String) -> DownloadRequest {
    shared.session.download(url).validate()
  }
  
  static func upload(multipartFormData: @escaping (MultipartFormData) -> Void, with convertable: URLRequestConvertible) -> UploadRequest {
    shared.session.upload(multipartFormData: multipartFormData, with: convertable).authenticate(username: ImaggaCredentials.username, password: ImaggaCredentials.password).validate()
  }
}
