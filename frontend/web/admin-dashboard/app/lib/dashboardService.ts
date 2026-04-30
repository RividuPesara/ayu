import { auth } from './firebase';

const BASE_URL = `${process.env.NEXT_PUBLIC_API_URL}/api/dashboard`;

async function getAuthHeaders() {
  const user = auth.currentUser;

  if (!user) {
    throw new Error('User not logged in');
  }

  const token = await user.getIdToken(true);

  return {
    Authorization: `Bearer ${token}`,
    'Content-Type': 'application/json',
  };
}

export async function fetchDashboardData() {
  const res = await fetch(BASE_URL, {
    method: 'GET',
    headers: await getAuthHeaders(),
  });

  if (!res.ok) {
    throw new Error(await res.text());
  }

  return res.json();
}