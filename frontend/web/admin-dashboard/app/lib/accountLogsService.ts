import { auth } from './firebase';
import { getIdToken } from 'firebase/auth';

const API_BASE = `${process.env.NEXT_PUBLIC_API_URL}/api/account-logs`;

export type UserType = 'Patient' | 'Companion' | 'Doctor' | 'Admin';

export type LogUser = {
  id: string;
  name: string;
  email: string;
  type: UserType;
  avatar?: string;
  createdAt: string;
  lastLogin: string;
};

async function getAuthHeaders() {
  const user = auth.currentUser;

  if (!user) {
    throw new Error('User not authenticated');
  }

  const token = await getIdToken(user);

  return {
    Authorization: `Bearer ${token}`,
    'Content-Type': 'application/json',
  };
}

export async function fetchAccountLogs(): Promise<LogUser[]> {
  const res = await fetch(API_BASE, {
    method: 'GET',
    headers: await getAuthHeaders(),
  });

  if (!res.ok) {
    throw new Error(await res.text());
  }

  return res.json();
}