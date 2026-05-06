const API_BASE_URL = "http://localhost:8000/api/articles";

// Types

export type ContentImage = {
  id: string;
  dataUrl: string;
  name: string;
};

export type Article = {
  id: string;
  title: string;
  genre: string;
  author: string;
  thumbnail: string;
  content: string;
  contentImages: ContentImage[];
  createdAt?: string;
};

export type CreateArticlePayload = {
  title: string;
  genre: string;
  author: string;
  thumbnail: string;
  content: string;
  contentImages: ContentImage[];
};

export type UpdateArticlePayload = CreateArticlePayload;

// Helper: Auth Header

async function getAuthHeaders(): Promise<HeadersInit> {
  const user = (await import("firebase/auth")).getAuth().currentUser;

  if (!user) throw new Error("User not authenticated");

  const token = await user.getIdToken();

  return {
    "Content-Type": "application/json",
    Authorization: `Bearer ${token}`,
  };
}

// API Calls

// Get all articles
export async function fetchArticles(): Promise<Article[]> {
  const headers = await getAuthHeaders();

  const res = await fetch(API_BASE_URL, {
    method: "GET",
    headers,
  });

  if (!res.ok) {
    throw new Error("Failed to fetch articles");
  }

  return res.json();
}

// Create article
export async function createArticle(
  data: CreateArticlePayload
): Promise<Article> {
  const headers = await getAuthHeaders();

  const res = await fetch(API_BASE_URL, {
    method: "POST",
    headers,
    body: JSON.stringify(data),
  });

  if (!res.ok) {
    const error = await res.json();
    throw new Error(error.detail || "Failed to create article");
  }

  return res.json();
}

// Get single article
export async function getArticle(id: string): Promise<Article> {
  const headers = await getAuthHeaders();

  const res = await fetch(`${API_BASE_URL}/${id}`, {
    method: "GET",
    headers,
  });

  if (!res.ok) {
    throw new Error("Article not found");
  }

  return res.json();
}

// Update article
export async function updateArticle(
  id: string,
  data: UpdateArticlePayload
): Promise<Article> {
  const headers = await getAuthHeaders();

  const res = await fetch(`${API_BASE_URL}/${id}`, {
    method: "PATCH",
    headers,
    body: JSON.stringify(data),
  });

  if (!res.ok) {
    const error = await res.json();
    throw new Error(error.detail || "Failed to update article");
  }

  return res.json();
}

// Delete article
export async function deleteArticle(id: string): Promise<void> {
  const headers = await getAuthHeaders();

  const res = await fetch(`${API_BASE_URL}/${id}`, {
    method: "DELETE",
    headers,
  });

  if (!res.ok) {
    throw new Error("Failed to delete article");
  }
}