import Flutter
import WatchConnectivity

public class WatchConnectivityPlugin: NSObject, FlutterPlugin, WCSessionDelegate {
    private let channel: FlutterMethodChannel
    private let session: WCSession?

    init(channel: FlutterMethodChannel) {
        self.channel = channel

        if WCSession.isSupported() {
            session = WCSession.default
        } else {
            session = nil
        }

        super.init()

        session?.delegate = self
        session?.activate()
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "watch_connectivity", binaryMessenger: registrar.messenger())
        let instance = WatchConnectivityPlugin(channel: channel)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isSupported":
            result(WCSession.isSupported())
        case "isPaired":
            result(session?.isPaired ?? false)
        case "isReachable":
            result(session?.isReachable ?? false)
        case "applicationContext":
            result(session?.applicationContext ?? [:])
        case "receivedApplicationContexts":
            result([session?.receivedApplicationContext ?? [:]])
        case "sendMessage":
            guard let message = call.arguments as? [String: Any] else {
                result(FlutterError(code: "invalid_arguments", message: "sendMessage expects a dictionary.", details: nil))
                return
            }
            guard let session else {
                result(FlutterError(code: "session_unavailable", message: "WatchConnectivity is not available on this device.", details: nil))
                return
            }
            session.sendMessage(message, replyHandler: nil)
            result(nil)
        case "updateApplicationContext":
            guard let context = call.arguments as? [String: Any] else {
                result(FlutterError(code: "invalid_arguments", message: "updateApplicationContext expects a dictionary.", details: nil))
                return
            }
            guard let session else {
                result(FlutterError(code: "session_unavailable", message: "WatchConnectivity is not available on this device.", details: nil))
                return
            }
            do {
                try session.updateApplicationContext(context)
                result(nil)
            } catch {
                result(FlutterError(code: "application_context_update_failed", message: error.localizedDescription, details: nil))
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        var arguments: [String: Any] = [
            "activationState": activationState.rawValue,
            "isActivated": activationState == .activated,
        ]

        if let error {
            NSLog("WatchConnectivity activation failed: %@", error.localizedDescription)
            arguments["error"] = [
                "code": "activation_failed",
                "message": error.localizedDescription,
            ]
        }

        channel.invokeMethod("activationDidComplete", arguments: arguments)
    }

    public func sessionDidBecomeInactive(_ session: WCSession) {}

    public func sessionDidDeactivate(_ session: WCSession) {}

    public func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        channel.invokeMethod("didReceiveMessage", arguments: message)
    }

    public func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        channel.invokeMethod("didReceiveApplicationContext", arguments: applicationContext)
    }
}
