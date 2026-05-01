const API_BASE = "http://localhost:8000/api/posts";

export type ContentImage = {
  id: string;
  dataUrl: string;
  name: string;
};

export type CreateArticlePayload = {
  title: string;
  genre: string;
  author: string;
  thumbnail: string;
  content: string;
  contentImages?: ContentImage[];
};

export type Article = {
  id: string;
  title: string;
  genre: string;
  author: string;
  thumbnail: string;
  content: string;
  published: boolean;
  contentImages?: ContentImage[];
};

/* Get Firebase token */
function getAuthHeader() {
  const token = localStorage.getItem("token");

  return {
    Authorization: `Bearer ${token}`,
    "Content-Type": "application/json",
  };
}

/* CREATE ARTICLE */
export async function createArticle(payload: CreateArticlePayload) {
  const res = await fetch(`${API_BASE}/`, {
    method: "POST",
    headers: getAuthHeader(),
    body: JSON.stringify(payload),
  });

  if (!res.ok) {
    const error = await res.json();
    throw new Error(error.detail || "Failed to create article");
  }

  return await res.json();
}

/* GET ALL ARTICLES */
export async function getArticles(): Promise<Article[]> {
  const res = await fetch(`${API_BASE}/`, {
    method: "GET",
    headers: getAuthHeader(),
  });

  if (!res.ok) {
    throw new Error("Failed to fetch articles");
  }

  return await res.json();
}

/* UPDATE ARTICLE */
export async function updateArticle(id: string, payload: Partial<CreateArticlePayload>) {
  const res = await fetch(`${API_BASE}/${id}`, {
    method: "PATCH",
    headers: getAuthHeader(),
    body: JSON.stringify(payload),
  });

  if (!res.ok) {
    const error = await res.json();
    throw new Error(error.detail || "Failed to update article");
  }

  return await res.json();
}

/* DELETE ARTICLE */
export async function deleteArticle(id: string) {
  const res = await fetch(`${API_BASE}/${id}`, {
    method: "DELETE",
    headers: getAuthHeader(),
  });

  if (!res.ok) {
    const error = await res.json();
    throw new Error(error.detail || "Failed to delete article");
  }

  return await res.json();
}

/* TOGGLE PUBLISH STATUS */
export async function toggleArticleStatus(id: string, published: boolean) {
  const res = await fetch(`${API_BASE}/${id}/status`, {
    method: "PATCH",
    headers: getAuthHeader(),
    body: JSON.stringify({ published }),
  });

  if (!res.ok) {
    const error = await res.json();
    throw new Error(error.detail || "Failed to update status");
  }

  return await res.json();
}