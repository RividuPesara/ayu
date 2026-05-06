import { auth } from "./firebase";

export type Doctor = {
  id: string;
  fullName: string;
  email: string;
  phone: string;
  address: string;
  slmcNumber: string;
  specialty: string;
  qualifications: string[];
  status: "Active" | "Archived" | "Suspended";
  avatar?: string;
  uid?: string;
};

export type CreateDoctorPayload = {
  fullName: string;
  email: string;
  password: string;
  phone: string;
  address: string;
  slmcNumber: string;
  specialty: string;
  qualifications: string[];
};

export type UpdateDoctorPayload = {
  fullName: string;
  email: string;
  phone: string;
  address: string;
  slmcNumber: string;
  specialty: string;
  qualifications: string[];
};

const BASE_URL = `http://localhost:8000/api/doctors`;

async function getAuthHeaders() {
  const user = auth.currentUser;

  if (!user) {
    throw new Error("User not logged in");
  }

  const token = await user.getIdToken();

  return {
    "Content-Type": "application/json",
    Authorization: `Bearer ${token}`,
  };
}

export async function fetchDoctors(): Promise<Doctor[]> {
  const headers = await getAuthHeaders();

  const res = await fetch(BASE_URL, { headers });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Fetch failed: ${text}`);
  }

  return res.json();
}

export async function createDoctor(
  data: CreateDoctorPayload
): Promise<Doctor> {
  const headers = await getAuthHeaders();

  const res = await fetch(BASE_URL, {
    method: "POST",
    headers,
    body: JSON.stringify(data),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Create failed: ${text}`);
  }

  return res.json();
}

export async function updateDoctorStatus(
  id: string,
  status: Doctor["status"]
): Promise<{ success: boolean }> {
  const headers = await getAuthHeaders();

  const res = await fetch(`${BASE_URL}/${id}/status`, {
    method: "PATCH",
    headers,
    body: JSON.stringify({ status }),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Update failed: ${text}`);
  }

  return res.json();
}

export async function updateDoctor(
  id: string,
  data: UpdateDoctorPayload
): Promise<Doctor> {
  const headers = await getAuthHeaders();

  const res = await fetch(`${BASE_URL}/${id}`, {
    method: "PATCH",
    headers,
    body: JSON.stringify(data),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Update doctor failed: ${text}`);
  }

  return res.json();
}