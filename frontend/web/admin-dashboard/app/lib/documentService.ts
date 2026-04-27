import { auth } from './firebase';

export type DocStatus = 'Pending' | 'Approved' | 'Rejected';

export type MedicalDocument = {
  id: string;
  patient: string;
  document: string;
  documentUrl: string;
  submitted: string;
  status: DocStatus;
  approvedForDonation: boolean;
  rejectionComment?: string;
};

const API_BASE = `${process.env.NEXT_PUBLIC_API_URL}/api/documents`;

async function getAuthToken(): Promise<string> {
  const user = auth.currentUser;

  if (!user) {
    throw new Error('User not logged in');
  }

  return await user.getIdToken();
}

export async function fetchMedicalDocuments(): Promise<MedicalDocument[]> {
  const token = await getAuthToken();

  const res = await fetch(API_BASE, {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${token}`,
    },
    cache: 'no-store',
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Failed to load documents: ${text}`);
  }

  return await res.json();
}

export async function approveMedicalDocument(id: string): Promise<void> {
  const token = await getAuthToken();

  const res = await fetch(`${API_BASE}/${id}/approve`, {
    method: 'PATCH',
    headers: {
      Authorization: `Bearer ${token}`,
    },
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Approve failed: ${text}`);
  }
}

export async function rejectMedicalDocument(
  id: string,
  comment: string
): Promise<void> {
  const token = await getAuthToken();

  const res = await fetch(`${API_BASE}/${id}/reject`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify({
      rejectionReason: comment,
    }),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Reject failed: ${text}`);
  }
}

export async function toggleDonationApproval(
  id: string,
  approvedForDonation: boolean
): Promise<void> {
  const token = await getAuthToken();

  const res = await fetch(`${API_BASE}/${id}/donation`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify({
      approvedForDonation,
    }),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Donation approval update failed: ${text}`);
  }
}