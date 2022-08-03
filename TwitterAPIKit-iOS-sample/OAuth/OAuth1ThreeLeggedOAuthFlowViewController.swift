import AuthenticationServices
import UIKit
import TwitterAPIKit

final class OAuth1ThreeLeggedOAuthFlowViewController: UIViewController {

    typealias Dependency = Env

    @IBOutlet private var consumerKeyLabel: UILabel!
    @IBOutlet private var consumerSecretLabel: UILabel!
    @IBOutlet private var oauthTokenLabel: UILabel!
    @IBOutlet private var oauthTokenSecretLabel: UILabel!

    private var env: Env
    private lazy var client: TwitterAPIClient = {
        guard let consumerKey = env.consumerKey, let consumerSecret = env.consumerSecret else { fatalError() }
        let client = TwitterAPIClient(.oauth10a(.init(consumerKey: consumerKey, consumerSecret: consumerSecret, oauthToken: nil, oauthTokenSecret: nil)))
        return client
    }()

    init?(coder: NSCoder, dependency: Env) {
        self.env = dependency
        super.init(coder: coder)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Sign in with OAuth 1.0a"
        updateLabel()
    }

    private func updateLabel() {
        consumerKeyLabel.text = "ConsumerKey: \(env.consumerKey ?? "nil")"
        consumerSecretLabel.text = "ConsumerSecret: \(env.consumerSecret ?? "nil")"
        oauthTokenLabel.text = "OAuthToken: \(env.oauthToken ?? "nil")"
        oauthTokenSecretLabel.text = "OAuthTokenSecret: \(env.oauthTokenSecret ?? "nil")"
    }

    @IBAction func tapSignInButton(_ sender: Any) {

        // 1. POST oauth/request_token (postOAuthRequestToken)
        // 2. GET oauth/authorize (makeOAuthAuthorizeURL & ASWebAuthenticationSession & parse callback url)
        // 3. POST oauth/access_token (postOAuthAccessToken)
        client.auth.oauth10a.postOAuthRequestToken(.init(oauthCallback: "twitter-api-kit-ios-sample://")) // Rewrite your oauth callback url or scheme
            .responseObject { [weak self] response in
                guard let self = self else { return }
                do {
                    let success = try response.result.get()
                    let url = self.client.auth.oauth10a.makeOAuthAuthorizeURL(.init(oauthToken: success.oauthToken))!

                    let session = ASWebAuthenticationSession(url: url, callbackURLScheme: "twitter-api-kit-ios-sample") { url, error in

                        // url is "twitter-api-kit-ios-sample://?oauth_token=<string>&oauth_verifier=<string>"
                        guard let url = url else {
                            if let error = error {
                                self.showAlert(title: "Error", message: error.localizedDescription)
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
                                do {
                                    let token = try response.result.get()
                                    let oauthToken = token.oauthToken
                                    let oauthTokenSecret = token.oauthTokenSecret

                                    self.env.oauthToken = oauthToken
                                    self.env.oauthTokenSecret = oauthTokenSecret
                                    self.env.store()
                                    self.updateLabel()

                                    self.showAlert(title: "Success!", message: nil) {
                                        self.navigationController?.popViewController(animated: true)
                                    }
                                } catch {
                                    self.showAlert(title: "Error", message: error.localizedDescription)
                                }
                            }
                    }
                    session.presentationContextProvider = self
                    session.prefersEphemeralWebBrowserSession = true

                    session.start()

                } catch {
                    self.showAlert(title: "Error", message: error.localizedDescription)
                }
            }
    }
}

extension OAuth1ThreeLeggedOAuthFlowViewController: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return view.window!
    }
}

extension OAuth1ThreeLeggedOAuthFlowViewController: StoryboardInstantiatable {}
