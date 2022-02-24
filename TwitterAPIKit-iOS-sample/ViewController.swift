//
//  ViewController.swift
//  TwitterAPIKit-iOS-sample
//
//

import AuthenticationServices
import UIKit
import TwitterAPIKit

let oauthTokenUserDefaultsKey = "oauthTokenUserDefaultsKey"
let oauthTokenSecretUserDefaultsKey = "oauthTokenSecretUserDefaultsKey"

// !! Please rewrite here !!
let consumerKey = "<Your Consumer Key>"
let consumerSecret = "<Your Consumer Secret>"

class ViewController: UIViewController {

    private lazy var client = TwitterAPIKit(
        .oauth(
            consumerKey: consumerKey,
            consumerSecret: consumerSecret,
            oauthToken: UserDefaults.standard.string(forKey: oauthTokenUserDefaultsKey),
            oauthTokenSecret: UserDefaults.standard.string(forKey: oauthTokenSecretUserDefaultsKey)
        )
    ) {
        didSet {
            updateButtonEnabled()
        }
    }

    @IBOutlet weak var signInButton: UIButton!
    @IBOutlet weak var signOutButton: UIButton!
    @IBOutlet weak var callButton: UIButton!

    @IBOutlet weak var resultText: UITextView!

    override func viewDidLoad() {
        super.viewDidLoad()

        updateButtonEnabled()
    }

    private func updateButtonEnabled() {
        switch client.apiAuth {
        case .oauth(consumerKey: _, consumerSecret: _, oauthToken: .some, oauthTokenSecret: .some):
            signInButton.isEnabled = false
        default:
            signInButton.isEnabled = true
        }

        callButton.isEnabled = !signInButton.isHeld
        signOutButton.isEnabled = !signInButton.isEnabled
    }

    @IBAction func tapSignIn(_ sender: Any) {

        // 1. POST oauth/request_token (postOAuthRequestToken)
        // 2. GET oauth/authorize (makeOAuthAuthorizeURL & ASWebAuthenticationSession & parse callback url)
        // 3. POST oauth/access_token (postOAuthAccessToken)

        client.v1.auth.postOAuthRequestToken(.init(oauthCallback: "twitter-api-kit-ios-sample://"))
            .responseObject { [weak self] response in
                guard let self = self else { return }
                do {
                    let success = try response.result.get()
                    let url = self.client.v1.auth.makeOAuthAuthorizeURL(.init(oauthToken: success.oauthToken))!

                    let session = ASWebAuthenticationSession(url: url, callbackURLScheme: "twitter-api-kit-ios-sample") { url, error in

                        // url is "twitter-api-kit-ios-sample://?oauth_token=<string>&oauth_verifier=<string>"

                        guard let url = url else {
                            if let error = error {
                                print("Error:", error)
                            }
                            return
                        }
                        print("URL:", url)

                        let component = URLComponents(url: url, resolvingAgainstBaseURL: false)
                        guard let oauthToken = component?.queryItems?.first(where: { $0.name == "oauth_token"} )?.value,
                              let oauthVerifier = component?.queryItems?.first(where: { $0.name == "oauth_verifier"})?.value else {
                                  print("Invalid URL")
                                  return
                              }
                        self.client.v1.auth.postOAuthAccessToken(.init(oauthToken: oauthToken, oauthVerifier: oauthVerifier))
                            .responseObject { response in

                                guard let success = response.success else {
                                    print("Error", String(describing: response.error))
                                    return
                                }

                                let oauthToken = success.oauthToken
                                let oauthTokenSecret = success.oauthTokenSecret
                                UserDefaults.standard.set(oauthToken, forKey: oauthTokenUserDefaultsKey)
                                UserDefaults.standard.set(oauthTokenSecret, forKey: oauthTokenSecretUserDefaultsKey)


                                self.client = .init(
                                    consumerKey: consumerKey,
                                    consumerSecret: consumerSecret,
                                    oauthToken: oauthToken,
                                    oauthTokenSecret: oauthTokenSecret
                                )
                            }
                    }
                    session.presentationContextProvider = self
                    session.prefersEphemeralWebBrowserSession = true

                    session.start()

                } catch let e {
                    print("Error", e)
                }
            }
    }

    @IBAction func tapSignOut(_ sender: Any) {

        UserDefaults.standard.removeObject(forKey: oauthTokenUserDefaultsKey)
        UserDefaults.standard.removeObject(forKey: oauthTokenSecretUserDefaultsKey)

        client = TwitterAPIKit(
            .oauth(
                consumerKey: consumerKey,
                consumerSecret: consumerSecret,
                oauthToken: nil,
                oauthTokenSecret: nil
            )
        )
    }

    @IBAction func tapCall(_ sender: Any) {

        if resultText.text == nil {
            resultText.text = ""
        }

        client
            // .v1
            // .getHomeTimeline(.init())
            // .postUpdateStatus(.init(status: "Hellooooo"))
            .v2
            .tweet.postTweet(.init(text: "blah-blah-blah"))
            .responseObject { [weak self] response in
                guard let self = self else { return }
                print(response.prettyString)

                var string = "---- \(Date().description) ----\n"
                string += response.prettyString
                string += "\n"
                string += self.resultText.text
                self.resultText.text = string
            }
    }
}

extension ViewController: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return view.window!
    }
}

