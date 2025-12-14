importScripts('https://www.gstatic.com/firebasejs/9.23.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.23.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBxwuL_CAEX8-MfTCh7dTb6CCAE3z2BUGA',
      appId: '1:418012865597:web:a584336328b75d976cf654',
      messagingSenderId: '418012865597',
      projectId: 'doan2-8a18f',
      authDomain: 'doan2-8a18f.firebaseapp.com',
      storageBucket: 'doan2-8a18f.firebasestorage.app',
      measurementId: 'G-GVYVCG64HR',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function (payload) {
  console.log('[firebase-messaging-sw.js] Received background message', payload);

  self.registration.showNotification(
    payload.notification?.title ?? 'Notification',
    {
      body: payload.notification?.body ?? '',
    }
  );
});
