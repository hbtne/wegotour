const admin = require("firebase-admin");
const fs = require("fs");

// 🔥 Đọc file JSON
const data = JSON.parse(fs.readFileSync("data.json", "utf8"));

// 🔥 Khởi tạo Firebase Admin SDK
const serviceAccount = require("./serviceAccountKey.json"); // 🔑 File Key tải từ Firebase
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// 🔥 Hàm import dữ liệu
const importData = async () => {
  for (const [collection, documents] of Object.entries(data)) {
    const collectionRef = db.collection(collection);

    for (const [docId, docData] of Object.entries(documents)) {
      await collectionRef.doc(docId).set(docData);
      console.log(`✅ Imported: ${collection}/${docId}`);
    }
  }

  console.log("🔥 Import completed!");
};

// 🏃‍♂️ Chạy script
importData().catch(console.error);
