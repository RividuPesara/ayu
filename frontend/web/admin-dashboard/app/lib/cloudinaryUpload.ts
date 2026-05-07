import axios from "axios";

export const uploadImage = async (file: File): Promise<string> => {
  const formData = new FormData();

  formData.append("file", file);
  formData.append("upload_preset", "community_posts");

  const res = await axios.post(
    "https://api.cloudinary.com/v1_1/duysmfmo4/image/upload",
    formData
  );

  return res.data.secure_url;
};