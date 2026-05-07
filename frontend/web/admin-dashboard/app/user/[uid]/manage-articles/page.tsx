"use client";

import { useState, useRef, useEffect } from "react";
import Image from "next/image";
import "../../../../styles/manage-articles.css";
import {
  collection,
  onSnapshot,
  doc,
  updateDoc,
} from "firebase/firestore";
import { db } from "../../../lib/firebase";
import { uploadImage } from '../../../lib/cloudinaryUpload';

type Article = {
  id: string;
  title: string;
  genre: string;
  author: string;
  thumbnail: string;
  content: string;
  published: boolean;
  contentImages?: ContentImage[];
};

type ContentImage = {
  id: string;
  dataUrl: string;
  name: string;
};

// Icons

const EditIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7" />
    <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z" />
  </svg>
);

const XIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <line x1="18" y1="6" x2="6" y2="18" />
    <line x1="6" y1="6" x2="18" y2="18" />
  </svg>
);

const SaveIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z" />
    <polyline points="17 21 17 13 7 13 7 21" />
    <polyline points="7 3 7 8 15 8" />
  </svg>
);

const CancelIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <circle cx="12" cy="12" r="10" />
    <line x1="15" y1="9" x2="9" y2="15" />
    <line x1="9" y1="9" x2="15" y2="15" />
  </svg>
);

const UploadIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
    <polyline points="17 8 12 3 7 8" />
    <line x1="12" y1="3" x2="12" y2="15" />
  </svg>
);

const ImageIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
    <rect x="3" y="3" width="18" height="18" rx="2" ry="2" />
    <circle cx="8.5" cy="8.5" r="1.5" />
    <polyline points="21 15 16 10 5 21" />
  </svg>
);

const NoImageIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
    <rect x="3" y="3" width="18" height="18" rx="2" ry="2" />
    <circle cx="8.5" cy="8.5" r="1.5" />
    <polyline points="21 15 16 10 5 21" />
    <line x1="2" y1="2" x2="22" y2="22" stroke="currentColor" strokeWidth="1.5" />
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

const TrashIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <polyline points="3 6 5 6 21 6" />
    <path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6" />
    <path d="M10 11v6M14 11v6" />
    <path d="M9 6V4h6v2" />
  </svg>
);

const EyeIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" />
    <circle cx="12" cy="12" r="3" />
  </svg>
);

// Render content with images inline
function renderContentWithImages(content: string, contentImages: ContentImage[]) {
  if (!contentImages || contentImages.length === 0) {
    return <p className="am-preview__content-text">{content}</p>;
  }

  const parts = content.split(/(!\[[^\]]*\]\([^)]*\))/g);
  return (
    <div className="am-preview__content-body">
      {parts.map((part, i) => {
        const match = part.match(/^!\[([^\]]*)\]\(([^)]*)\)$/);
        if (match) {
          const imgId = match[1];
          const img = contentImages.find((ci) => ci.id === imgId);
          if (img) {
            return (
              <img
                key={i}
                src={img.dataUrl}
                alt={img.name}
                className="am-preview__content-image"
              />
            );
          }
        }
        return part ? <span key={i} className="am-preview__content-text">{part}</span> : null;
      })}
    </div>
  );
}

// Main Page

export default function ManageArticles() {
  const [articles, setArticles] = useState<Article[]>([]);
  const [editTarget, setEditTarget] = useState<Article | null>(null);
  const [previewTarget, setPreviewTarget] = useState<Article | null>(null);
  const [pageLoading, setPageLoading] = useState(true);

  useEffect(() => {
    setPageLoading(true);
    const unsub = onSnapshot(collection(db, "articles"), (snapshot) => {
      const data: Article[] = snapshot.docs.map((docSnap) => ({
        id: docSnap.id,
        ...(docSnap.data() as Omit<Article, "id">),
      }));
      setArticles(data);
      setPageLoading(false);
    });

    return () => unsub();
  }, []); 

  const togglePublished = async (id: string, current: boolean) => {
    await updateDoc(doc(db, "articles", id), {
      published: !current,}
    );
  };

  const handleEditSave = async (updated: Article) => {
    const { id, ...data } = updated;
    await updateDoc(doc(db, "articles", id), data);
    setEditTarget(null);
  };

  return (
    <div>
      <div className="am-page-header">
        <h1 className="am-page-title">Manage Articles</h1>
        <p className="am-page-subtitle">Edit, publish, or unpublish articles.</p>
      </div>

      {pageLoading ? (
        <div className="ac-page-loader">
          <div className="ac-page-loader__spinner" />
          <p className="ac-page-loader__text">
            Loading manage articles...
          </p>
        </div>
      ) : (

      <div className="am-grid">
        {articles.map((article) => (
          <div key={article.id} className="am-card">

            <div className="am-card__thumbnail">
              {article.thumbnail ? (
                <Image src={article.thumbnail} alt={article.title} fill className="am-card__img" sizes="(max-width: 768px) 100vw, (max-width: 1200px) 50vw, 33vw" />
              ) : (
                <div className="am-card__no-thumbnail">
                  <NoImageIcon />
                  <span>No thumbnail</span>
                </div>
              )}
            </div>

            <div className="am-card__body">
              {/* Clickable title */}
              <button
                className="am-card__title-btn"
                onClick={() => setPreviewTarget(article)}
                title="Preview article"
              >
                {article.title}
              </button>

              <div className="am-card__footer">
                <div className="am-card__toggle-row">
                  <button
                    onClick={() => togglePublished(article.id, article.published)}
                    className={`am-toggle ${article.published ? "am-toggle--on" : "am-toggle--off"}`}
                  >
                    <span className={`am-toggle__thumb ${article.published ? "am-toggle__thumb--on" : "am-toggle__thumb--off"}`} />
                  </button>
                  <span className="am-card__status">
                    {article.published ? "Published" : "Draft"}
                  </span>
                </div>

                <button className="am-edit-btn" onClick={() => setEditTarget({ ...article })}>
                  <EditIcon />
                </button>
              </div>
            </div>

          </div>
        ))}
      </div>
      )}

      {/* Preview Dialog */}
      {previewTarget && (
        <PreviewDialog
          article={previewTarget}
          onClose={() => setPreviewTarget(null)}
        />
      )}

      {/* Edit Dialog */}
      {editTarget && (
        <EditDialog
          article={editTarget}
          onClose={() => setEditTarget(null)}
          onSave={handleEditSave}
        />
      )}
    </div>
  );
}

// Preview Dialog

function PreviewDialog({
  article,
  onClose,
}: {
  article: Article;
  onClose: () => void;
}) {
  return (
    <div className="am-dialog-overlay" onClick={(e) => { if (e.target === e.currentTarget) onClose(); }}>
      <div className="am-dialog am-dialog--preview">

        <div className="am-dialog__header">
          <div>
            <h2 className="am-dialog__title">{article.title}</h2>
            <p className="am-dialog__subtitle">{article.genre} · {article.author}</p>
          </div>
          <button onClick={onClose} className="am-dialog__close"><XIcon /></button>
        </div>

        <div className="am-dialog__body">

          {/* Status badge */}
          <div className="am-preview__meta">
            <span className={`am-preview__badge ${article.published ? "am-preview__badge--published" : "am-preview__badge--draft"}`}>
              {article.published ? "Published" : "Draft"}
            </span>
          </div>

          {/* Content */}
          <div className="am-preview__content">
            {renderContentWithImages(article.content, article.contentImages ?? [])}
          </div>

        </div>

        <div className="am-dialog__footer">
          <button onClick={onClose} className="am-dialog__save">
            <EyeIcon /> Close Preview
          </button>
        </div>

      </div>
    </div>
  );
}

// Edit Dialog

function EditDialog({
  article,
  onClose,
  onSave,
}: {
  article: Article;
  onClose: () => void;
  onSave: (updated: Article) => void;
}) {
  const [form, setForm] = useState<Article>({ ...article });
  const [contentImages, setContentImages] = useState<ContentImage[]>(article.contentImages || []);
  const [errors, setErrors] = useState<Partial<Record<keyof Article, string>>>({});
  const [thumbnailFileName, setThumbnailFileName] = useState("");
  const fileInputRef = useRef<HTMLInputElement>(null);
  const contentImageInputRef = useRef<HTMLInputElement>(null);
  const contentTextareaRef = useRef<HTMLTextAreaElement>(null);

  const setField = (field: keyof Article, value: string) => {
    setForm((prev) => ({ ...prev, [field]: value }));
    setErrors((prev) => ({ ...prev, [field]: undefined }));
  };

  const handleFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
      const url = await uploadImage(file);
      setField("thumbnail", url);
      setThumbnailFileName(file.name);
    
  };

  const handleContentImageInsert = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const url = await uploadImage(file);
    
      const id = `img_${Date.now()}`;
      const tag = `![${id}](${file.name})`;

      setForm((prev) => ({
      ...prev,
      content: prev.content + "\n" + tag + "\n",
    }));

    setContentImages((prev) => [
      ...prev,
      { id, dataUrl: url, name: file.name },
    ]);
    };

  const removeContentImage = (id: string) => {
    setContentImages((prev) => prev.filter((img) => img.id !== id));
    setForm((prev) => ({
      ...prev,
      content: prev.content.replace(
        new RegExp(`!\\[${id}\\]\\([^)]*\\)`, "g"),
        ""
      ),
    }));
  };

  const validate = () => {
    const newErrors: Partial<Record<keyof Article, string>> = {};
    if (!form.title.trim())     newErrors.title     = "Title is required.";
    if (!form.genre.trim())     newErrors.genre     = "Genre is required.";
    if (!form.author.trim())    newErrors.author    = "Author is required.";
    if (!form.content.trim())   newErrors.content   = "Content is required.";
    if (!form.thumbnail.trim()) newErrors.thumbnail = "Please upload a thumbnail image.";
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSave = () => {
    if (!validate()) return;
    onSave({ ...form, contentImages });
  };

  return (
    <div className="am-dialog-overlay" onClick={(e) => { if (e.target === e.currentTarget) onClose(); }}>
      <div className="am-dialog">

        <div className="am-dialog__header">
          <div>
            <h2 className="am-dialog__title">Edit Article</h2>
            <p className="am-dialog__subtitle">Update the details for your article below.</p>
          </div>
          <button onClick={onClose} className="am-dialog__close"><XIcon /></button>
        </div>

        <div className="am-dialog__body">

          {/* Title */}
          <div className="am-dialog__field">
            <label className="am-dialog__label">Article Title</label>
            <input
              type="text"
              value={form.title}
              onChange={(e) => setField("title", e.target.value)}
              className={`am-dialog__input${errors.title ? " am-dialog__input--error" : ""}`}
            />
            {errors.title && <p className="am-dialog__error">{errors.title}</p>}
          </div>

          {/* Genre + Author */}
          <div className="am-dialog__row">
            <div className="am-dialog__field">
              <label className="am-dialog__label">Genre</label>
              <input
                type="text"
                value={form.genre}
                onChange={(e) => setField("genre", e.target.value)}
                className={`am-dialog__input${errors.genre ? " am-dialog__input--error" : ""}`}
              />
              {errors.genre && <p className="am-dialog__error">{errors.genre}</p>}
            </div>
            <div className="am-dialog__field">
              <label className="am-dialog__label">Author</label>
              <input
                type="text"
                value={form.author}
                onChange={(e) => setField("author", e.target.value)}
                className={`am-dialog__input${errors.author ? " am-dialog__input--error" : ""}`}
              />
              {errors.author && <p className="am-dialog__error">{errors.author}</p>}
            </div>
          </div>

          {/* Thumbnail */}
          <div className="am-dialog__field">
            <label className="am-dialog__label">Thumbnail Image</label>
            <div
              className={`am-dialog__dropzone${errors.thumbnail ? " am-dialog__input--error" : ""}`}
              onClick={() => fileInputRef.current?.click()}
            >
              {form.thumbnail ? (
                <div className="am-dialog__dropzone-preview">
                  <Image src={form.thumbnail} alt="Thumbnail preview" fill sizes="(max-width: 768px) 100vw, 33vw" className="am-dialog__dropzone-img" />
                  <div className="am-dialog__dropzone-overlay">
                    <UploadIcon />
                    <span>Change image</span>
                  </div>
                </div>
              ) : (
                <div className="am-dialog__dropzone-empty">
                  <ImageIcon />
                  <p className="am-dialog__dropzone-text">Click to upload a thumbnail</p>
                  <p className="am-dialog__dropzone-hint">PNG, JPG, WEBP — max 5 MB</p>
                </div>
              )}
            </div>
            {thumbnailFileName && <p className="am-dialog__filename">📎 {thumbnailFileName}</p>}
            <input ref={fileInputRef} type="file" accept="image/*" style={{ display: "none" }} onChange={handleFileChange} />
            {errors.thumbnail && <p className="am-dialog__error">{errors.thumbnail}</p>}
          </div>

          {/* Content */}
          <div className="am-dialog__field">
            <div className="am-dialog__content-label-row">
              <label className="am-dialog__label">Content</label>
              <button
                type="button"
                className="am-dialog__insert-img-btn"
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
              rows={7}
              value={form.content}
              onChange={(e) => setField("content", e.target.value)}
              className={`am-dialog__textarea${errors.content ? " am-dialog__input--error" : ""}`}
            />
            {/* Content image previews */}
            {contentImages.length > 0 && (
              <div className="am-dialog__content-images">
                {contentImages.map((img) => (
                  <div key={img.id} className="am-dialog__content-image-item">
                    <img src={img.dataUrl} alt={img.name} className="am-dialog__content-image-preview" />
                    <div className="am-dialog__content-image-meta">
                      <span className="am-dialog__content-image-name">{img.name}</span>
                      <button
                        type="button"
                        className="am-dialog__content-image-remove"
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
            {errors.content && <p className="am-dialog__error">{errors.content}</p>}
          </div>

        </div>

        <div className="am-dialog__footer">
          <button onClick={onClose} className="am-dialog__cancel">
            <CancelIcon /> Cancel
          </button>
          <button onClick={handleSave} className="am-dialog__save">
            <SaveIcon /> Save Changes
          </button>
        </div>

      </div>
    </div>
  );
}