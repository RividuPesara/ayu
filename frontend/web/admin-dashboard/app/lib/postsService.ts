import { auth } from './firebase'; 
import { uploadImage } from './cloudinaryUpload';

/* Post Types */
export type PostType = 'status' | 'photo' | 'story';

export type PostStatus = 'pending' | 'approved' | 'rejected';

export type CommunityPost = {
  id: string;
  type: PostType;
  authorId: string;
  authorName: string;
  authorHandle?: string;
  authorAvatar?: string;

  text?: string;
  caption?: string;
  title?: string;
  content?: string;
  imageURL?: string;


  status: string;
  createdAt: { seconds: number } | null;
};

export type CreateCommunityPostPayload = {
  type: PostType;
  imageURL: string;
  text: string;
  caption: string;
  title: string;
  content: string;
  authorName: string;
};

const MODERATION_API_BASE = `${process.env.NEXT_PUBLIC_API_URL}/api/moderation/posts`;
const POSTS_API_BASE = `${process.env.NEXT_PUBLIC_API_URL}/api/posts`;

async function getAuthHeaders() {
  const user = auth.currentUser;

  if (!user) {
    throw new Error('User not logged in');
  }

  const token = await user.getIdToken();

  return {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${token}`,
  };
}

export async function fetchPosts(
  status: PostStatus | null
): Promise<CommunityPost[]> {
  const headers = await getAuthHeaders();

  const url = status
    ? `${MODERATION_API_BASE}?status=${status}`
    : MODERATION_API_BASE;

  const res = await fetch(url, {
    method: 'GET',
    headers,
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Failed to load posts: ${text}`);
  }

  return res.json();
}

export function subscribeToPosts(
  status: PostStatus | null,
  onData: (posts: CommunityPost[]) => void,
  onError: (err: Error) => void
): () => void {
  let cancelled = false;

  const load = async () => {
    try {
      const posts = await fetchPosts(status);
      if (!cancelled) onData(posts);
    } catch (err) {
      if (!cancelled) onError(err as Error);
    }
  };

  load();
  const interval = setInterval(load, 3000);

  return () => {
    cancelled = true;
    clearInterval(interval);
  };
}

/* Mutations */
export async function approvePost(postId: string): Promise<void> {
  const headers = await getAuthHeaders();

  const res = await fetch(`${MODERATION_API_BASE}/${postId}/approve`, {
    method: 'PATCH',
    headers,
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Approve failed: ${text}`);
  }
}

export async function rejectPost(postId: string): Promise<void> {
  const headers = await getAuthHeaders();

  const res = await fetch(`${MODERATION_API_BASE}/${postId}/reject`, {
    method: 'PATCH',
    headers,
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Reject failed: ${text}`);
  }
}

export async function uploadCommunityImage(file: File): Promise<string> {
  return uploadImage(file);
}

export async function createCommunityPost(
  payload: CreateCommunityPostPayload
): Promise<void> {
  const headers = await getAuthHeaders();

  const res = await fetch(`${POSTS_API_BASE}/create`, {
    method: 'POST',
    headers,
    body: JSON.stringify(payload),
  });

  const result = await res.json().catch(() => null);

  if (!res.ok) {
    throw new Error(result?.detail || result?.message || 'Failed to create post');
  }
}