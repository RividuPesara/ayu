import { auth } from "@/app/lib/firebase";
import { onAuthStateChanged, User } from "firebase/auth";

const BACKEND_BASE_URL =
  process.env.NEXT_PUBLIC_BACKEND_URL || "http://127.0.0.1:8000";

// Backend URL used by the doctor dashboard
export function getBackendBaseUrl(): string {
  return BACKEND_BASE_URL;
}

// Waits for Firebase auth state if user isnt immediately available
async function waitForCurrentUser(): Promise<User | null> {
  if (auth.currentUser) {
    return auth.currentUser;
  }
  return new Promise((resolve) => {
    const timeout = setTimeout(() => {
      unsubscribe();
      resolve(null);
    }, 3000);
    const unsubscribe = onAuthStateChanged(auth, (user) => {
      clearTimeout(timeout);
      unsubscribe();
      resolve(user);
    });
  });
}

// Gets a Firebase ID token from the currently sign in user
export async function getAuthToken(): Promise<string> {
  const currentUser = await waitForCurrentUser();
  if (!currentUser) {
    throw new Error("No authenticated user found.");
  }
  return currentUser.getIdToken(true);
}

// Makes an authenticated request to the backend API
export async function backendRequest<T>(
  path: string,
  init: RequestInit = {},
): Promise<T> {
  const token = await getAuthToken();

  const headers = new Headers(init.headers ?? {});
  headers.set("Authorization", `Bearer ${token}`);

  if (init.body && !(init.body instanceof FormData) && !headers.has("Content-Type")) {
    headers.set("Content-Type", "application/json");
  }
  const response = await fetch(`${getBackendBaseUrl()}${path}`, {...init,headers,});

  if (!response.ok) {
    const message = await response.text();
    throw new Error(message || `Request failed with status ${response.status}`);
  }

  if (response.status === 204) {
    return undefined as T;
  }
  return (await response.json()) as T;
}
