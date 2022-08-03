import Foundation
import UIKit

extension UIViewController {

    func showAlert(title: String?, message: String?, tapOK block: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(.init(title: "OK", style: .default) { _ in
            block?()
        })
        present(alert, animated: true)
    }
}
