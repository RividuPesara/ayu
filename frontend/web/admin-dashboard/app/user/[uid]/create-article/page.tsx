"use client";

import { useState, useRef } from "react";
import Image from "next/image";
import "../../../../styles/create-article.css";

type ArticleForm = {
  title: string;
  genre: string;
  author: string;
  thumbnail: string;
  content: string;
};

type ContentImage = {
  id: string;
  dataUrl: string;
  name: string;
};

const emptyForm: ArticleForm = {
  title: "",
  genre: "",
  author: "",
  thumbnail: "",
  content: "",
};

const genreOptions = ["Stress", "Health", "Status", "Edu"];

// Icons

const PlusCircleIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <circle cx="12" cy="12" r="10" />
    <line x1="12" y1="8" x2="12" y2="16" />
    <line x1="8" y1="12" x2="16" y2="12" />
  </svg>
);

const UploadIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
    <polyline points="17 8 12 3 7 8" />
    <line x1="12" y1="3" x2="12" y2="15" />
  </svg>
);

const ImagePlusIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <rect x="3" y="3" width="18" height="18" rx="2" ry="2" />
    <circle cx="8.5" cy="8.5" r="1.5" />
    <polyline points="21 15 16 10 5 21" />
    <line x1="16" y1="5" x2="16" y2="11" />
    <line x1="13" y1="8" x2="19" y2="8" />
  </svg>
);

const ImageIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
    <rect x="3" y="3" width="18" height="18" rx="2" ry="2" />
    <circle cx="8.5" cy="8.5" r="1.5" />
    <polyline points="21 15 16 10 5 21" />
  </svg>
);

const TrashIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <polyline points="3 6 5 6 21 6" />
    <path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6" />
    <path d="M10 11v6M14 11v6" />
    <path d="M9 6V4h6v2" />
  </svg>
);

// Main Page

export default function CreateArticle() {
  const [form, setForm] = useState<ArticleForm>(emptyForm);
  const [errors, setErrors] = useState<Partial<ArticleForm>>({});
  const [submitted, setSubmitted] = useState(false);
  const [thumbnailFileName, setThumbnailFileName] = useState<string>("");
  const [contentImages, setContentImages] = useState<ContentImage[]>([]);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const contentImageInputRef = useRef<HTMLInputElement>(null);
  const contentTextareaRef = useRef<HTMLTextAreaElement>(null);

  const set = (field: keyof ArticleForm, value: string) => {
    setForm((prev) => ({ ...prev, [field]: value }));
    setErrors((prev) => ({ ...prev, [field]: undefined }));
  };

  const validate = (): boolean => {
    const newErrors: Partial<ArticleForm> = {};
    if (!form.title.trim())   newErrors.title   = "Article title is required.";
    if (!form.genre.trim())   newErrors.genre   = "Genre is required.";
    if (!form.author.trim())  newErrors.author  = "Author is required.";
    if (!form.thumbnail.trim())  newErrors.thumbnail  = "Thumbnail is required.";
    if (!form.content.trim()) newErrors.content = "Content is required.";
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = () => {
    if (!validate()) return;
    setSubmitted(true);
    setForm(emptyForm);
    setContentImages([]);
    setThumbnailFileName("");
    setTimeout(() => setSubmitted(false), 3000);
  };

  const handleThumbnailChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      set("thumbnail", URL.createObjectURL(file));
      setThumbnailFileName(file.name);
      setErrors((prev) => ({ ...prev, thumbnail: undefined }));
    }
  };

  const handleContentImageInsert = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = () => {
      const dataUrl = reader.result as string;
      const id = `img_${Date.now()}`;
      const tag = `![${id}](${file.name})`;

      const textarea = contentTextareaRef.current;
      if (textarea) {
        const start = textarea.selectionStart ?? form.content.length;
        const end = textarea.selectionEnd ?? form.content.length;
        const newContent =
          form.content.substring(0, start) +
          (start > 0 && form.content[start - 1] !== "\n" ? "\n" : "") +
          tag + "\n" +
          form.content.substring(end);
        set("content", newContent);
      } else {
        set("content", form.content + "\n" + tag + "\n");
      }

      setContentImages((prev) => [...prev, { id, dataUrl, name: file.name }]);
    };
    reader.readAsDataURL(file);
    e.target.value = "";
  };

  const removeContentImage = (id: string) => {
    setContentImages((prev) => prev.filter((img) => img.id !== id));
    const tagRegex = new RegExp(`\\n?!\\[${id}\\]\\([^)]*\\)\\n?`, "g");
    set("content", form.content.replace(tagRegex, "\n").trim());
  };

  return (
    <div>
      {/* Page Header */}
      <div className="ac-page-header">
        <h1 className="ac-page-title">Create Article</h1>
        <p className="ac-page-subtitle">Fill in the details below to create a new article.</p>
      </div>

      {/* Card */}
      <div className="ac-card">
        <div className="ac-card-header">
          <h2 className="ac-card-title">New Article</h2>
          <p className="ac-card-subtitle">Add a title, author, genre, and content for your article.</p>
        </div>

        <div className="ac-card-body">

          {submitted && (
            <div className="ac-success">Article created successfully!</div>
          )}

          {/* Article Title */}
          <div className="ac-field">
            <label className="ac-label">Article Title</label>
            <input
              type="text"
              placeholder="Title..."
              value={form.title}
              onChange={(e) => set("title", e.target.value)}
              className={`ac-input${errors.title ? " ac-input--error" : ""}`}
            />
            {errors.title && <p className="ac-error">{errors.title}</p>}
          </div>

          {/* Genre and Author row */}
          <div className="ac-row">
            <div className="ac-field">
              <label className="ac-label">Genre</label>
              <select
                value={form.genre}
                onChange={(e) => set("genre", e.target.value)}
                className={`ac-input${errors.genre ? " ac-input--error" : ""}`}
              >
                <option value="">Select an option</option>
                {genreOptions.map((option) => (
                  <option key={option} value={option}>{option}</option>
                ))}
              </select>
              {errors.genre && <p className="ac-error">{errors.genre}</p>}
            </div>
            <div className="ac-field">
              <label className="ac-label">Author</label>
              <input
                type="text"
                placeholder="Dr. Evelyn Reed"
                value={form.author}
                onChange={(e) => set("author", e.target.value)}
                className={`ac-input${errors.author ? " ac-input--error" : ""}`}
              />
              {errors.author && <p className="ac-error">{errors.author}</p>}
            </div>
          </div>

          {/* Thumbnail — dropzone */}
          <div className="ac-field">
            <label className="ac-label">Thumbnail Image</label>
            <div
              className={`ac-dropzone${errors.thumbnail ? " ac-input--error" : ""}`}
              onClick={() => fileInputRef.current?.click()}
            >
              {form.thumbnail ? (
                <div className="ac-dropzone__preview">
                  <Image
                    src={form.thumbnail}
                    alt="Thumbnail preview"
                    fill
                    className="ac-dropzone__img"
                  />
                  
                  {errors.thumbnail && <p className="ac-error">{errors.thumbnail}</p>}
                  
                  <div className="ac-dropzone__overlay">
                    <UploadIcon />
                    <span>Change image</span>
                  </div>
                </div>
              ) : (
                <div className="ac-dropzone__empty">
                  <ImageIcon />
                  <p className="ac-dropzone__text">Click to upload a thumbnail</p>
                  <p className="ac-dropzone__hint">PNG, JPG, WEBP — max 5 MB</p>
                </div>
              )}
            </div>
            {thumbnailFileName && (
              <p className="ac-filename">📎 {thumbnailFileName}</p>
            )}
            <input
              ref={fileInputRef}
              type="file"
              accept="image/*"
              style={{ display: "none" }}
              onChange={handleThumbnailChange}
            />
            {errors.thumbnail && <p className="ac-error">{errors.thumbnail}</p>}
          </div>

          {/* Content */}
          <div className="ac-field">
            <div className="ac-content-label-row">
              <label className="ac-label">Content</label>
              <button
                type="button"
                className="ac-upload-btn"
                onClick={() => contentImageInputRef.current?.click()}
                title="Insert image into content"
              >
                <ImagePlusIcon /> Insert Image
              </button>
              <input
                ref={contentImageInputRef}
                type="file"
                accept="image/*"
                style={{ display: "none" }}
                onChange={handleContentImageInsert}
              />
            </div>
            <textarea
              ref={contentTextareaRef}
              rows={10}
              placeholder="Write your article content here..."
              value={form.content}
              onChange={(e) => set("content", e.target.value)}
              className={`ac-textarea${errors.content ? " ac-input--error" : ""}`}
            />
            {/* Inserted content images */}
            {contentImages.length > 0 && (
              <div className="ac-content-images">
                {contentImages.map((img) => (
                  <div key={img.id} className="ac-content-image-item">
                    <img src={img.dataUrl} alt={img.name} className="ac-content-image-preview" />
                    <div className="ac-content-image-meta">
                      <span className="ac-content-image-name">{img.name}</span>
                      <button
                        type="button"
                        className="ac-content-image-remove"
                        onClick={() => removeContentImage(img.id)}
                        title="Remove image"
                      >
                        <TrashIcon /> Remove
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            )}
            {errors.content && <p className="ac-error">{errors.content}</p>}
          </div>

        </div>

        {/* Footer */}
        <div className="ac-card-footer">
          <button onClick={handleSubmit} className="ac-submit-btn">
            <PlusCircleIcon /> Create Article
          </button>
        </div>
      </div>
    </div>
  );
}