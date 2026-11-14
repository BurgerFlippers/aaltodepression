import SwiftUI
import MessageUI

/// Messages compose sheet, pre-filled. iOS never lets an app send by itself; Perttu taps send.
struct MessageCompose: UIViewControllerRepresentable {
    let recipient: String
    let body: String
    var onResult: ((MessageComposeResult) -> Void)? = nil
    var onFinish: () -> Void

    static var canSend: Bool { MFMessageComposeViewController.canSendText() }

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let vc = MFMessageComposeViewController()
        vc.recipients = recipient.isEmpty ? [] : [recipient]
        vc.body = body
        vc.messageComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: MFMessageComposeViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish, onResult: onResult) }

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let onFinish: () -> Void
        let onResult: ((MessageComposeResult) -> Void)?
        init(onFinish: @escaping () -> Void, onResult: ((MessageComposeResult) -> Void)?) { self.onFinish = onFinish; self.onResult = onResult }
        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            MainActor.assumeIsolated { onResult?(result); onFinish() }
        }
    }
}
