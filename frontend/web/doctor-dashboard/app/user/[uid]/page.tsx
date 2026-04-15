"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import { doc, getDoc } from "firebase/firestore";
import { db } from "@/app/lib/firebase";

export default function Dashboard() {
  const params = useParams();
  const uid = params.uid as string;

  const [userData, setUserData] = useState<any>(null);

  useEffect(() => {
    const fetchUser = async () => {
      try {
        const docRef = doc(db, "doctors", uid);
        const docSnap = await getDoc(docRef);

        if (docSnap.exists()) {
          setUserData(docSnap.data());
        } else {
          console.log("No user document found");
        }
      } catch (error) {
        console.error("Error fetching user:", error);
      }
    };

    if (uid) {
      fetchUser();
    }
  }, [uid]);

  if (!userData) {
    return <div>Loading...</div>;
  }

  return (
    <div style={{ color: "black" }}>
      <h1>Doctor Dashboard</h1>
      <p>Welcome, {userData.fullName}</p>
    </div>
  );
}