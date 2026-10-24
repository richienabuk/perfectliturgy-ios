# Mobile notifications

App-wide notifications for the Android app. The server can send any message. One Firebase Cloud Messaging **data** message can carry a title, a body, and an image link together.

The phone posts the shade itself. A tap leaves the current screen in place and opens the notice in the same bottom sheet as the rest of the app. The sheet shows the title, the body when the message includes one, and the picture when `image` is an `https` URL.

---

## Payload

Send a data message. Omit the FCM `notification` block. With only that block, a backgrounded app lets Android draw the shade, and the tap does not bring the title and body into the notice screen.

Every data value is a string.

| Key | Required | Meaning |
| :--- | :---: | :--- |
| `title` | yes | The message. Shade title and the screen heading. |
| `body` | no | Longer text under the title. Omit the key when there is nothing more to say. |
| `image` | no | Public `https` URL of a JPEG or PNG. The file stays on the web. Do not put image bytes in the payload. |

```json
{
  "message": {
    "token": "DEVICE_FCM_TOKEN",
    "data": {
      "title": "A message",
      "body": "There is something new in the app.",
      "image": "https://perfectliturgy.com/notices/message.jpg"
    }
  }
}
```

Title only:

```json
{
  "message": {
    "token": "DEVICE_FCM_TOKEN",
    "data": {
      "title": "A message"
    }
  }
}
```

Keep the data block under 4 KB. A photo will not fit. Host the file and send the URL.

Picture file:

- `https` only
- JPEG or PNG
- Under 1 MB

Copy stays short and plain, in the voice of a parish bulletin. One fact. No exclamation marks.

---

## What the app does

`LiturgyMessagingService` reads `title` and `body` from the data block and posts a notification on the channel **Notifications**.

A tap opens `MainActivity` and raises the notice sheet over the screen that was already open:

- The title is the sheet heading.
- The body is the paragraph under it, when present.
- `image` is shown in the sheet when it is an `https` URL.

The registration token is stored on the device in shared preferences `liturgy_notices`, key `fcm_token`. On Android 13 and above, the first launch asks for notification permission. Allowing it `POST`s the token to `/v1/devices` with `platform: android`. Older Android grants that permission at install, so the first open registers without a prompt.

A signed-in session sends `Authorization: Bearer <session>` so the server can store the token on the Account. The first registration is often signed out. The next sign-in sends the token once more, with the session. The device remembers the token and Account id already accepted by the server, and does not send again for that same login. A new Account, or a new FCM token, sends once. Sign-out does not send. A test send can still target a token you copy off the phone.

The app accepts messages only after `app/google-services.json` is present and the debug app is rebuilt. The Google services plugin applies when that file exists.

---

## Server

Use the Firebase project that owns the Android app id `com.perfectliturgy`. Enable the Firebase Cloud Messaging API. Create a service account that can send messages, and keep its JSON key on the server. Do not put that key in the app repo.

`google-services.json` belongs in `app/` for the client. It is not the server credential.

Send with the HTTP v1 API:

```text
POST https://fcm.googleapis.com/v1/projects/PROJECT_ID/messages:send
Authorization: Bearer ACCESS_TOKEN
Content-Type: application/json
```

`ACCESS_TOKEN` is an OAuth token for the service account, scope `https://www.googleapis.com/auth/firebase.messaging`.

Node, with `firebase-admin`:

```js
const admin = require("firebase-admin");

admin.initializeApp({
  credential: admin.credential.cert(require("./firebase-service-account.json")),
});

await admin.messaging().send({
  token: deviceToken,
  data: {
    title: "A message",
    body: "There is something new in the app.",
    image: "https://perfectliturgy.com/notices/message.jpg",
  },
});
```

Pass `data` only. Do not also set `notification`, or a backgrounded phone will skip `LiturgyMessagingService`.

The app registers each install that allows notifications. Tests can still pass a token by hand. `POST /v1/devices` stores `token` against the Account when the request carries a session.

---

## Send a test

1. Download `google-services.json` for Android app `com.perfectliturgy` and put it in `app/`.
2. Rebuild and install the debug app. Allow notifications when asked.
3. Read the token from the debug app:

```bash
adb shell run-as com.perfectliturgy cat shared_prefs/liturgy_notices.xml
```

Copy the `fcm_token` string. If the file is missing, open the app once after the rebuild so Firebase can issue a token.

4. Send the data message with curl. Replace `PROJECT_ID`, `ACCESS_TOKEN`, and `DEVICE_FCM_TOKEN`.

```bash
curl -X POST \
  "https://fcm.googleapis.com/v1/projects/PROJECT_ID/messages:send" \
  -H "Authorization: Bearer ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "message": {
      "token": "DEVICE_FCM_TOKEN",
      "data": {
        "title": "A message",
        "body": "There is something new in the app.",
        "image": "https://perfectliturgy.com/notices/message.jpg"
      }
    }
  }'
```

A 200 response contains a message name like `projects/PROJECT_ID/messages/0:...`.

5. On the phone:

- The shade shows **A message**, with the body on the expanded row.
- A tap opens the app and raises a sheet over the current screen. The heading is **A message**. The paragraph is **There is something new in the app.** The picture is in the sheet when `image` is an `https` URL.

Send again with `title` alone to confirm a message with no body. The shade and the screen show that one line.

### Firebase console

Open **DevOps & Engagement → Messaging → Create your first campaign → Notifications**. The test dialog on that form has no custom-data fields. Notification title and notification text are enough.

1. Notification title: `A message`. Notification text: `There is something new in the app.`
2. **Send test message**, and paste `fcm_token`.

The app copies that title, text, and image link onto the tap. A tap raises the notice sheet with the same title, text, and picture. The page underneath stays where it was.
