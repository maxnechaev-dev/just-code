//
//  PlannerApp.swift
//  Planner
//
//  Created by Max Nechaev on 03.05.2024.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth
import UserNotifications
import RevenueCat
import AmplitudeSwift
import FirebaseAnalytics
import AppsFlyerLib
import AdSupport
import Firebase
import UserNotifications
import FirebaseMessaging

@main
struct PlannerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @AppStorage(AppConstants.hasSeenOnboarding) var hasSeenOnboarding: Bool = false

    @StateObject var router = Router.shared
    @StateObject var userManager = UserManager.shared

    typealias Localizable = LocalizedString.TabBar

    init() {
        setupTabBarAppearance()
        Purchases.configure(withAPIKey: AppConstants.revenueCatApiKey)
    }

    var body: some Scene {
        WindowGroup {
            if hasSeenOnboarding {
                runMainFlow()
            } else {
                OnboardingAssembly().build()
            }
        }
    }

    @ViewBuilder
    private func runMainFlow() -> some View {
        TabView {
            MainPageAssembly().build()
                .tabItem {
                    Label(Localizable.home.localized, image: Images.TabBar.home)
                }
            MainCalendarAssembly().build()
                .tabItem {
                    Label(Localizable.calendar.localized, image: Images.TabBar.calendar)
                }
            StatisticsAssembly().build()
                .tabItem {
                    Label(Localizable.statistics.localized, image: Images.TabBar.statistics)
                }
            SettingsAssembly().build()
                .tabItem {
                    Label(Localizable.settings.localized, image: Images.TabBar.settings)
                }
        }
        .tint(Color(hex: "DB8132"))
    }

    private func setupTabBarAppearance() {
        let fontDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body).withDesign(.rounded) ?? UIFontDescriptor()
        let font = UIFont(descriptor: fontDescriptor, size: 11).withWeight(.semibold)
        UITabBarItem.appearance().setTitleTextAttributes([.font: font], for: .normal)
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {

        AppsFlyerLib.shared().appsFlyerDevKey = AppConstants.appsflyerDevKey
        AppsFlyerLib.shared().appleAppID = AppConstants.appAppleIdWithID
        AppsFlyerLib.shared().delegate = self
        FirebaseApp.configure()
        Auth.auth().signInAnonymously { [weak self] (authResult, error) in
            if let error = error {
                self?.setupServicesIfAuthFailed(error.localizedDescription)
            } else if let result = authResult {
                self?.setupServices(
                    with: result.user.uid,
                    isNewUser: result.additionalUserInfo?.isNewUser ?? false
                )
            }
        }

        let center = UNUserNotificationCenter.current()
        center.delegate = self

        center.getNotificationSettings { settings in
            if settings.authorizationStatus == .authorized {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }

        Messaging.messaging().delegate = self

        return true
    }

    func appsflyerSetup() {
        if UserManager.shared.isFirstUserSession {
            AppsFlyerLib.shared().waitForATTUserAuthorization(timeoutInterval: 120)
        }
        AppsFlyerLib.shared().customerUserID = UserManager.shared.userId
        AppsFlyerLib.shared().start()
        Purchases.shared.attribution.setAppsflyerID(AppsFlyerLib.shared().getAppsFlyerUID())
        if UserManager.shared.isFirstUserSession {
            TimefyAnalytics.shared.sendAppsflyerEvent(event: .afCompleteRegistration)
        } else {
            TimefyAnalytics.shared.sendAppsflyerEvent(event: .afLogin)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.sound, .badge, .banner])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("Notification received: \(userInfo)")
        completionHandler()
    }

    private func setupServices(with userId: String, isNewUser: Bool) {
        UserManager.shared.userId = userId
        UserManager.shared.isFirstUserSession = isNewUser
        Purchases.shared.logIn(userId, completion: {_, _, _ in })
        UserManager.shared.checkSubscriptionStatus()
        TimefyAmplitude.shared.setUserId(userId)
        Purchases.shared.attribution.collectDeviceIdentifiers()
        if isNewUser {
            TimefyAnalytics.shared.sendEvent(event: .userSignedUp, types: [.amplitude, .firebase])
        }
        appsflyerSetup()

        // Setup Firebase with RevenueCat
        if let instanceID = Analytics.appInstanceID() {
            Purchases.shared.attribution.setFirebaseAppInstanceID(instanceID)
        }
    }

    private func setupServicesIfAuthFailed(_ error: String) {
        if !UserManager.shared.userId.isEmpty {
            setupServices(with: UserManager.shared.userId, isNewUser: false)
            return
        } else {
            UserManager.shared.checkSubscriptionStatus()
            let _ = TimefyAmplitude.shared
            TimefyAnalytics.shared.sendEvent(event: .userSignUpFailed)
            AppsFlyerLib.shared().waitForATTUserAuthorization(timeoutInterval: 120)
            AppsFlyerLib.shared().start()
            Purchases.shared.attribution.collectDeviceIdentifiers()
            Purchases.shared.attribution.setAppsflyerID(AppsFlyerLib.shared().getAppsFlyerUID())
        }
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("FCM Token: \(fcmToken ?? "None")")
    }
}

extension AppDelegate: AppsFlyerLibDelegate {
    func onConversionDataSuccess(_ data: [AnyHashable: Any]) {
        if let isFirstLaunch = data["is_first_launch"] as? Int, isFirstLaunch == 1 {
            let source = data["media_source"] as? String ?? "Unknown"
            let afStatus = data["af_status"] as? String ?? "Unknown"
            TimefyAnalytics.shared.sendEvent(event: .installSource(.init(
                source: source,
                status: afStatus,
                error: ""
            )))
        }
    }

    func onConversionDataFail(_ error: Error) {
        if UserManager.shared.isFirstUserSession {
            TimefyAnalytics.shared.sendEvent(event: .installSource(.init(
                source: "",
                status: "",
                error: error.localizedDescription
            )))
        }
    }
}
