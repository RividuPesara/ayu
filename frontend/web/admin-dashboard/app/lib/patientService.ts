import { auth } from './firebase';
import { getIdToken } from 'firebase/auth';

const BASE_URL = "http://localhost:8000/api/patient";

async function getAuthHeaders() {
  const user = auth.currentUser;
  if (!user) {
    throw new Error('User not authenticated');
  }
  const token = await getIdToken(user);
  return {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json',
  };
}

export type Status = "Active" | "Archived" | "Suspended";

export type Patient = {
  id: string;
  uid?: string;
  name: string;
  email: string;
  status: Status;
  donationApproved: boolean;
  companionName?: string;
  companionEmail?: string;
  cancerType?: string;
  stage?: string;
  avatar?: string;
};

export type PatientDetails = Patient & {
  firstName?: string;
  lastName?: string;
  patientProfile?: {
    cancerType?: string;
    stage?: string;
  };
  createdAt?: any;
  updatedAt?: any;
};

export const fetchPatients = async (): Promise<Patient[]> => {
  const headers = await getAuthHeaders();
  const res = await fetch(`${BASE_URL}/`, {
    headers,
  });

  if (!res.ok) {
    throw new Error("Failed to fetch patients");
  }

  return res.json();
};

export const fetchPatientById = async (id: string): Promise<PatientDetails> => {
  const headers = await getAuthHeaders();
  const res = await fetch(`${BASE_URL}/${id}`, {
    headers,
  });

  if (!res.ok) {
    throw new Error("Failed to fetch patient");
  }

  return res.json();
};

export const updatePatientStatus = async (
  id: string,
  status: Status
) => {
  const headers = await getAuthHeaders();
  const res = await fetch(`${BASE_URL}/${id}`, {
    method: "PUT",
    headers,
    body: JSON.stringify({ status }),
  });

  if (!res.ok) {
    throw new Error("Failed to update patient");
  }

  return res.json();
};