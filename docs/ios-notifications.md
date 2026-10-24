# iOS notices with Firebase

The iPhone app uses Firebase Cloud Messaging. Firebase delivers through Apple Push Notification service. The app registers the Firebase token with `POST /v1/devices` as `platform: ios`. The server sends that token. Do not send the raw APNs device token. The API looks it up as a Firebase token.

The service-account JSON stays on the server. It does not belong in this repo.

## 1. Apple Developer

1. Open the App ID `com.perfectliturgy`.
2. Enable **Push Notifications** and **Background Modes** (Background fetch and Remote notifications).
3. Create an APNs Auth Key (a `.p8` file). Note the Key ID and your Team ID `2KA43TTV35`. You can download the `.p8` file once.

The project already sets the `aps-environment` entitlement (`development` for Debug, `production` for Release) and the background modes in `PerfectLiturgy/Info.plist`.

## 2. Firebase

1. Open the Firebase project that already owns the Android app `com.perfectliturgy`.
2. Add an iOS app with bundle id `com.perfectliturgy`.
3. Download `GoogleService-Info.plist`.
4. Put that file in `PerfectLiturgy/` (next to `Info.plist`). The Xcode folder is synchronized, so a rebuild picks it up. Until the file is there, the app launches and skips notice registration.
5. In Firebase, open **Project settings → Cloud Messaging → Apple app configuration**. Upload the APNs Auth Key, Key ID, and Team ID.

Enable the Firebase Cloud Messaging API for the project. The server already sends with `FIREBASE_SERVICE_ACCOUNT_JSON`.

## 3. What the app does

On launch, if `GoogleService-Info.plist` is in the bundle, the app asks for notification permission and asks Apple for a remote-notification registration. Firebase turns that into a registration token.

The app `POST`s `{ "token": "<fcm token>", "platform": "ios" }` to `{API_BASE_URL}/v1/devices`.

- Signed out: the request has no `Authorization` header. That first registration is allowed.
- After sign-in: the same token is sent again with `Authorization: Bearer <session>` so the Account is attached.
- The same token and Account are not sent twice.
- Sign-out does not send.

A message should include the data keys and an `aps` alert. The alert is what a backgrounded iPhone shows as the banner. A tap leaves the current screen in place and opens a sheet with the title, the body when there is one, and the picture when `image` is an `https` JPEG or PNG.

```json
{
  "message": {
    "token": "DEVICE_FCM_TOKEN",
    "notification": {
      "title": "A message",
      "body": "There is something new in the app."
    },
    "data": {
      "title": "A message",
      "body": "There is something new in the app.",
      "image": "https://perfectliturgy.com/notices/message.jpg"
    },
    "apns": {
      "payload": {
        "aps": {
          "alert": {
            "title": "A message",
            "body": "There is something new in the app."
          },
          "sound": "default"
        }
      }
    }
  }
}
```

Every data value is a string. Keep the data block under 4 KB. Host the picture. Do not put image bytes in the payload.

## 4. Send a test

1. Add `GoogleService-Info.plist`, then run the Debug scheme on a real iPhone. The simulator does not register for remote notifications.
2. Allow notifications.
3. In the Xcode console, filter for the Firebase Messaging token, or read it from the device log after the first launch. The app stores the token it last sent under UserDefaults keys `notices.fcmToken` and `notices.account`.
4. Send the message above with the HTTP v1 API. `ACCESS_TOKEN` is an OAuth token for the server service account, scope `https://www.googleapis.com/auth/firebase.messaging`.

```bash
curl -X POST \
  "https://fcm.googleapis.com/v1/projects/PROJECT_ID/messages:send" \
  -H "Authorization: Bearer ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d @message.json
```

A 200 response contains a message name like `projects/PROJECT_ID/messages/0:...`.

On the phone:

- The banner title is **A message**. The body is **There is something new in the app.**
- A tap opens the sheet over the screen that was already open. The heading is **A message**. The paragraph is the body. The picture is in the sheet when `image` is an `https` JPEG or PNG.

Send again with `title` alone to confirm a message with no body. The banner and the sheet show that one line.
