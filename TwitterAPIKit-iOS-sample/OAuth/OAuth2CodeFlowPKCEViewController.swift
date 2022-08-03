import AuthenticationServices
import UIKit
import TwitterAPIKit

final class OAuth2CodeFlowPKCEViewController: UIViewController {

    typealias Dependency = Env

    @IBOutlet private var authTypeSegment: UISegmentedControl!
    private var env: Env
    private var client: TwitterAPIClient!

    init?(coder: NSCoder, dependency: Dependency) {
        self.env = dependency
        super.init(coder: coder)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Sign in with OAuth 2.0 Authorization Code Flow with PKCE"

        if env.clientID == nil || env.clientID == "<Your Client ID>" {
            showAlert(title: "Error", message: "Replace the 'clientID' with your app's one.")
        }
        updateClient()
    }

    @IBAction func authTypeChanged(_ sender: UISegmentedControl) {
        updateClient()
    }

    @IBAction func tapSignInButton(_ sender: Any) {

        let state = "<state_here>" // Rewrite your state

        let clientID = env.clientID!
        let authorizeURL = client.auth.oauth20.makeOAuth2AuthorizeURL(.init(
            clientID: clientID,
            redirectURI: "twitter-api-kit-ios-sample://", // Rewrite your scheme
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
                clientID: clientID,
                redirectURI: "twitter-api-kit-ios-sample://", codeVerifier: "code challenge"
            )).responseObject { response in
                do {
                    let token = try response.result.get()
                    self.env.oauthToken = nil
                    self.env.token = .init(clientID: clientID, token: token)
                    self.env.store()
                    self.showAlert(title: "Success!", message: nil) {
                        self.navigationController?.popViewController(animated: true)
                    }
                } catch let error {
                    self.showAlert(title: "Error", message: error.localizedDescription)
                }
            }
        }

        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = true

        session.start()
    }

    // MARK: - Private

    private func updateClient() {
        switch authTypeSegment.selectedSegmentIndex {
        case 0:
            client = TwitterAPIClient(.requestOAuth20WithPKCE(.confidentialClient(
                clientID: env.clientID!,
                clientSecret: env.clientSecret!
            )))
        case 1:
            client = TwitterAPIClient(.requestOAuth20WithPKCE(.publicClient))
        default:
            fatalError("Invalid index")
        }
    }
}

extension OAuth2CodeFlowPKCEViewController: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return view.window!
    }
}

extension OAuth2CodeFlowPKCEViewController: StoryboardInstantiatable {}
