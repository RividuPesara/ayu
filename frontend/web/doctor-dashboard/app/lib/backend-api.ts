import { auth } from "@/app/lib/firebase";
import { onAuthStateChanged, User } from "firebase/auth";

const BACKEND_BASE_URL =
  process.env.NEXT_PUBLIC_BACKEND_URL || "http://127.0.0.1";

export class UnauthenticatedError extends Error {
  constructor(message = "No authenticated user found.") {
    super(message);
    this.name = "UnauthenticatedError";
  }
}

// Backend URL used by the doctor dashboard
export function getBackendBaseUrl(): string {
  return BACKEND_BASE_URL;
}

let _resolvedUser: User | null = null;
let _authReady = false;
let _authReadyPromise: Promise<void> | null = null;

// waits until firebase auth is ready
function ensureAuthListener(): Promise<void> {
  if (_authReadyPromise) {
    return _authReadyPromise;
  }
  _authReadyPromise = new Promise<void>((resolve) => {
    const timeout = setTimeout(() => {
      _authReady = true;
      resolve();
    }, 3000);
    // listen for login and logout changes
    onAuthStateChanged(auth, (user) => {
      _resolvedUser = user;
      if (!_authReady) {
        clearTimeout(timeout);
        _authReady = true;
        resolve();
      }
    });
  });
  return _authReadyPromise;
}

// Gets a Firebase ID token from the currently sign in user
export async function getAuthToken(): Promise<string> {
  if (auth.currentUser) {
    return auth.currentUser.getIdToken();
  }

  await ensureAuthListener();

  const user = _resolvedUser ?? auth.currentUser;
  if (!user) {
    throw new UnauthenticatedError();
  }
  return user.getIdToken();
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

  if (response.status === 401 || response.status === 403) {
    throw new UnauthenticatedError("Authentication required.");
  }

  if (!response.ok) {
    const message = await response.text();
    throw new Error(message || `Request failed with status ${response.status}`);
  }

  if (response.status === 204) {
    return undefined as T;
  }
  return (await response.json()) as T;
}
