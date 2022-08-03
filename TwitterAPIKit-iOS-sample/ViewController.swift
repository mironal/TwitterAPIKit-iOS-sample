import UIKit
import TwitterAPIKit

// !! Please rewrite here !!

// When authenticating with OAuth 1.0a, rewrite consumerKey and consumerSecret.
private let consumerKey = "<Your Consumer Key>"
private let consumerSecret = "<Your Consumer Secret>"

// If you want to authenticate with OAuth 20 Public Client, please rewrite the clientID.
// When authenticating with OAuth 20's Confidential Client, rewrite clientID and Client Secret.
// For more information, please visit https://github.com/mironal/TwitterAPIKit/blob/main/HowDoIAuthenticate.md
private let clientID = "<Your Client ID>"
private let clientSecret = "<Your Client Secret>"

final class ViewController: UITableViewController {

    @IBOutlet private var authInfoCell: UITableViewCell!
    @IBOutlet private var signInWithOAuth10aCell: UITableViewCell!
    @IBOutlet private var signInWithOAuth20Cell: UITableViewCell!
    @IBOutlet private var refreshConfidentialCell: UITableViewCell!
    @IBOutlet private var refreshPublicCell: UITableViewCell!
    @IBOutlet private var resetCell: UITableViewCell!
    @IBOutlet private var getAccountVerifyCredentialsCell: UITableViewCell!
    @IBOutlet private var getUsersMeCell: UITableViewCell!
    
    private var env: Env {
        if let env = Env.restore() {
            return env
        }
        return Env(
            consumerKey: consumerKey,
            consumerSecret: consumerSecret,
            oauthToken: nil,
            oauthTokenSecret: nil,
            clientID: clientID,
            clientSecret: clientSecret
        )
    }

    var client: TwitterAPIClient! {
        didSet {
            if client == nil {
                authInfoCell.textLabel?.text = "Not Auth"
            } else if case .oauth10a = client.apiAuth {
                authInfoCell.textLabel?.text = "Currently authenticated with OAuth 1.0a"
            } else if case .oauth20 = client.apiAuth {
                authInfoCell.textLabel?.text = "Currently authenticated with OAuth 2.0"
            }
            tableView.reloadData()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "TwitterAPIKit sample"

        NotificationCenter.default.addObserver(self, selector: #selector(didRefreshOAuth20Token(_:)), name: TwitterAPIClient.didRefreshOAuth20Token, object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        client = createClient()
    }

    @objc func didRefreshOAuth20Token(_ notification: Notification) {

        guard let token = notification.userInfo?[TwitterAPIClient.tokenUserInfoKey] as? TwitterAuthenticationMethod.OAuth20 else {
            fatalError()
        }
        print("didRefreshOAuth20Token", didRefreshOAuth20Token, token)
    }

    // MARK: - Private

    private func createClient() -> TwitterAPIClient? {
        if let consumerKey = env.consumerKey,
           let consumerSecret = env.consumerSecret,
           let oauthToken = env.oauthToken,
           let oauthTokenSecret = env.oauthTokenSecret {
            return TwitterAPIClient(.oauth10a(.init(
                consumerKey: consumerKey,
                consumerSecret: consumerSecret,
                oauthToken: oauthToken,
                oauthTokenSecret: oauthTokenSecret
            )))
        } else if let accessToken = env.token {
            return TwitterAPIClient(.oauth20(accessToken))
        }
        return nil
    }

    private func showRequestResult(text: String) {
        let vc = RequestResultViewController.instantiateInitialViewController(text)
        let nav = UINavigationController(rootViewController: vc)
        self.present(nav, animated: true)
    }

    private func confirmReset() {
        let alert = UIAlertController(title: nil, message: "Reset", preferredStyle: .alert)
        alert.addAction(.init(title: "Reset", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            Env.reset()
            self.client = self.createClient()
        })
        alert.addAction(.init(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func refreshAndStoreToken(clientType: TwitterAuthenticationMethod.OAuth20WithPKCEClientType) async {

        guard let client = client, case .oauth20 = client.apiAuth else {
            showAlert(title: "Error", message: "Refresh is available only when you are authenticating with OAuth 2.0.")
            return
        }
        do {
            let refresh = try await client.refreshOAuth20Token(type: .confidentialClient(clientID: env.clientID!, clientSecret: env.clientSecret!), forceRefresh: true)
            if refresh.refreshed {
                var env = self.env
                env.token = refresh.token
                env.store()
                self.client = createClient()
            }
            showAlert(title: nil, message: "Success Refresh")
        } catch {
            showAlert(title: "Error", message: error.localizedDescription)
        }
    }
}

extension ViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let cell = tableView.cellForRow(at: indexPath)
        switch cell {
        case signInWithOAuth10aCell:
            let vc = OAuth1ThreeLeggedOAuthFlowViewController.instantiateInitialViewController(env)
            navigationController?.pushViewController(vc, animated: true)
        case signInWithOAuth20Cell:
            let vc = OAuth2CodeFlowPKCEViewController.instantiateInitialViewController(env)
            navigationController?.pushViewController(vc, animated: true)
        case refreshConfidentialCell:
            Task {
                await refreshAndStoreToken(clientType: .confidentialClient(clientID: env.clientID!, clientSecret: env.clientSecret!))
            }
        case refreshPublicCell:
            Task {
                await refreshAndStoreToken(clientType: .publicClient)
            }
        case resetCell:
            confirmReset()
        case getAccountVerifyCredentialsCell:
            Task {
                let response = await client.v1.account.getAccountVerify(.init()).responseData
                print(response.prettyString)
                showRequestResult(text: response.prettyString)
            }
        case getUsersMeCell:
            Task {
                let response = await client.v2.user.getMe(.init()).responseData
                print(response.prettyString)
                showRequestResult(text: response.prettyString)
            }
        default:
            break
        }
    }
}
