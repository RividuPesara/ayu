import { auth } from "./firebase";

const BASE_URL = `http://localhost:8000/api/sidebar`;

async function getAuthHeaders() {
  const user = auth.currentUser;

  if (!user) {
    throw new Error("User not logged in");
  }

  const token = await user.getIdToken();

  return {
    Authorization: `Bearer ${token}`,
    "Content-Type": "application/json",
  };
}

export async function getSidebarUser(uid: string) {
  const res = await fetch(`${BASE_URL}/${uid}`, {
    method: "GET",
    headers: await getAuthHeaders(),
  });

  if (!res.ok) {
    throw new Error(await res.text());
  }

  return res.json();
}