import BackgroundTasks
import FirebaseCore
import FirebaseMessaging
import os
import UIKit
import UserNotifications

private let noticeLog = Logger(subsystem: "com.perfectliturgy", category: "notices")

final class PushDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        BackgroundSync.register()
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            noticeLog.notice("GoogleService-Info.plist is missing. Notices stay off until it is added.")
            return true
        }
        FirebaseApp.configure()
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        // Authorization finishes off the main actor. Do not inherit MainActor on this callback.
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { @Sendable granted, _ in
            guard granted else { return }
            Task { @MainActor in
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        noticeLog.error("Remote notification registration failed")
    }

    /// Firebase may deliver this off the main actor.
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        let token = fcmToken
        Task { @MainActor in
            await NoticeCenter.shared.tokenArrived(token)
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let notice = NoticePayload.notice(from: response.notification.request.content.userInfo)
        Task { @MainActor in
            NoticeCenter.shared.present(notice)
        }
        completionHandler()
    }
}
