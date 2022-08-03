import UIKit

final class RequestResultViewController: UIViewController {
    typealias Dependency = String

    @IBOutlet private var textView: UITextView! {
        didSet {
            textView.text = text
        }
    }

    private let text: String

    init?(coder: NSCoder, dependency: String) {
        self.text = dependency
        super.init(coder: coder)
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Result"
    }

    @IBAction func didPushDone(_ sender: Any) {
        dismiss(animated: true)
    }
}

extension RequestResultViewController: StoryboardInstantiatable {}
