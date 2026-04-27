import { auth } from './firebase';
import { getIdToken } from 'firebase/auth';

const BASE_URL = process.env.NEXT_PUBLIC_API_URL + "/api/feed";

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

async function handleResponse(res: Response) {
  if (!res.ok) {
    const text = await res.text();
    throw new Error(text || `HTTP error! status: ${res.status}`);
  }
  return res.json();
}

export async function fetchFeed() {
  const res = await fetch(`${BASE_URL}/`);
  return handleResponse(res);
}

export async function fetchComments(postId: string) {
  const res = await fetch(`${BASE_URL}/${postId}/comments`);
  return handleResponse(res);
}

export async function likePost(postId: string) {
  const headers = await getAuthHeaders();
  const res = await fetch(`${BASE_URL}/${postId}/like`, {
    method: "POST",
    headers,
  });
  return handleResponse(res);
}

export async function addComment(
  postId: string,
  authorName: string,
  text: string
) {
  const headers = await getAuthHeaders();
  const res = await fetch(
    `${BASE_URL}/${postId}/comment?authorName=${encodeURIComponent(authorName)}&text=${encodeURIComponent(text)}`,
    {
      method: "POST",
      headers,
    }
  );

  return handleResponse(res);
}