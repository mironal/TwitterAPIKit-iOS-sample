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
let oauth2AccessTokenUserDefaultsKey = "oauth2AccessTokenUserDefaultsKey"
let oauth2RefreshTokenUserDefultsKey = "oauth2RefreshTokenUserDefultsKey"

// !! Please rewrite here !!
let consumerKey = "<Your Consumer Key>"
let consumerSecret = "<Your Consumer Secret>"
let oauth2ClientID = "<Your Client ID>"

class ViewController: UIViewController {

    private lazy var client: TwitterAPIKit = {
        if let accessToken = UserDefaults.standard.string(forKey: oauth2AccessTokenUserDefaultsKey) {
            return TwitterAPIKit(.bearer(accessToken))
        } else {
            return TwitterAPIKit(
                .oauth(
                    consumerKey: consumerKey,
                    consumerSecret: consumerSecret,
                    oauthToken: UserDefaults.standard.string(forKey: oauthTokenUserDefaultsKey),
                    oauthTokenSecret: UserDefaults.standard.string(forKey: oauthTokenSecretUserDefaultsKey)
                )
            )
        }
    }() {
        didSet {
            updateAuthStateUI()
        }
    }

    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var signInButton: UIButton!
    @IBOutlet weak var signInOAuth2Button: UIButton!
    @IBOutlet weak var signOutButton: UIButton!
    @IBOutlet weak var callButton: UIButton!

    @IBOutlet weak var resultText: UITextView!

    override func viewDidLoad() {
        super.viewDidLoad()

        updateAuthStateUI()
    }

    private func updateAuthStateUI() {
        switch client.apiAuth {
        case .oauth(consumerKey: _, consumerSecret: _, oauthToken: .some, oauthTokenSecret: .some):
            signInButton.isEnabled = false
            signInOAuth2Button.isEnabled = false
            infoLabel.text = "Authed by OAuth1.1a"
        case .bearer:
            signInButton.isEnabled = false
            signInOAuth2Button.isEnabled = false
            infoLabel.text = "Authed by OAuth2.0"
        default:
            signInButton.isEnabled = true
            signInOAuth2Button.isEnabled = true
            infoLabel.text = "Not authed"
        }

        callButton.isEnabled = !signInButton.isHeld
        signOutButton.isEnabled = !signInButton.isEnabled
    }

    @IBAction func tapSignIn(_ sender: Any) {

        // 1. POST oauth/request_token (postOAuthRequestToken)
        // 2. GET oauth/authorize (makeOAuthAuthorizeURL & ASWebAuthenticationSession & parse callback url)
        // 3. POST oauth/access_token (postOAuthAccessToken)

        client.auth.oauth10a.postOAuthRequestToken(.init(oauthCallback: "twitter-api-kit-ios-sample://"))
            .responseObject { [weak self] response in
                guard let self = self else { return }
                do {
                    let success = try response.result.get()
                    let url = self.client.auth.oauth10a.makeOAuthAuthorizeURL(.init(oauthToken: success.oauthToken))!

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
                        self.client.auth.oauth10a.postOAuthAccessToken(.init(oauthToken: oauthToken, oauthVerifier: oauthVerifier))
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


    @IBAction func tapSignInOAuth2(_ sender: Any) {

        // Public Client example

        let state = "<state_here>"

        self.client = TwitterAPIKit(.none)
        let authorizeURL = client.auth.oauth20.makeOAuth2AuthorizeURL(.init(
            clientID: oauth2ClientID,
            redirectURI: "twitter-api-kit-ios-sample://",
            state: state,
            codeChallenge: "code challenge",
            codeChallengeMethod: "plain", // OR S256
            scopes: ["tweet.read", "tweet.write", "users.read", "offline.access"]
        ))!

        let session = ASWebAuthenticationSession(url: authorizeURL, callbackURLScheme: "twitter-api-kit-ios-sample") { [weak self] url, error in
            guard let self = self else { return }

            guard let url = url else {
                print(error!)
                return
            }
            print("return url", url)

            let component = URLComponents(url: url, resolvingAgainstBaseURL: false)

            guard let returnedState = component?.queryItems?.first(where: {$0.name == "state"})?.value,
                  let code = component?.queryItems?.first(where: { $0.name == "code" })?.value else {
                      print("Invalid return url")
                      return
                  }
            guard state == returnedState else {
                print("Invalid state", state, returnedState)
                return
            }

            self.client.auth.oauth20.postOAuth2AccessToken(.init(
                code: code,
                clientID: oauth2ClientID,
                redirectURI: "twitter-api-kit-ios-sample://", codeVerifier: "code challenge"
            )).responseObject { response in
                do {
                    let token = try response.result.get()
                    UserDefaults.standard.set(token.accessToken, forKey: oauth2AccessTokenUserDefaultsKey)
                    UserDefaults.standard.set(token.refreshToken, forKey: oauth2RefreshTokenUserDefultsKey)
                    self.client = .init(.bearer(token.accessToken))
                    print("Success!")
                } catch let error {
                    print("Error", error)
                }
            }
        }

        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = true

        session.start()

    }

    @IBAction func tapSignOut(_ sender: Any) {

        UserDefaults.standard.removeObject(forKey: oauthTokenUserDefaultsKey)
        UserDefaults.standard.removeObject(forKey: oauthTokenSecretUserDefaultsKey)
        UserDefaults.standard.removeObject(forKey: oauth2AccessTokenUserDefaultsKey)
        UserDefaults.standard.removeObject(forKey: oauth2RefreshTokenUserDefultsKey)

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

