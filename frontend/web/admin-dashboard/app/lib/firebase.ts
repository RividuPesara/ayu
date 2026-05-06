import { initializeApp } from "firebase/app";
import { getAuth } from "firebase/auth";
import { getFirestore } from "firebase/firestore";

const firebaseConfig = {
  apiKey: "AIzaSyDAEn9Px1ZJo_3inyM071RlbPX1QACdVTg",
  authDomain: "ayuproject-64a7b.firebaseapp.com",
  projectId: "ayuproject-64a7b",
  storageBucket: "ayuproject-64a7b.firebasestorage.app",
  messagingSenderId: "1035485819117",
  appId: "1:1035485819117:web:de36156c0fcd83e95d9ce4"

};

const app = initializeApp(firebaseConfig);

export const auth = getAuth(app);
export const db = getFirestore(app);
