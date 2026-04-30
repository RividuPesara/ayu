const BASE_URL = `${process.env.NEXT_PUBLIC_API_URL}/api/profile`;

export async function getProfile(uid: string) {
  const res = await fetch(`${BASE_URL}/${uid}`);

  if (!res.ok) {
    throw new Error(await res.text());
  }

  return res.json();
}

export async function updateProfile(data: {
  uid: string;
  firstName: string;
  lastName: string;
  email: string;
  avatar?: string;
  newPassword?: string;
}) {
  const res = await fetch(`${BASE_URL}/update`, {
    method: "PUT",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      ...data,
      avatar: data.avatar || "",
    }),
  });

  if (!res.ok) {
    throw new Error(await res.text());
  }

  return res.json();
}