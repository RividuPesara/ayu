'use client';

import { useState, useRef } from 'react';
import { addDoc, collection, serverTimestamp } from 'firebase/firestore';
import { db, auth } from '../../../lib/firebase';
import { uploadImage } from '../../../lib/cloudinaryUpload';
import { useRouter } from 'next/navigation';
import '../../../../styles/create-post.css';

/* Color Palette */
const colors = [
  { value: '#8863ca', label: 'Violet'  },
  { value: '#34B7F1', label: 'Blue'    },
  { value: '#5B8DEF', label: 'Cyan'    },
  { value: '#38ca6e', label: 'Green'   },
  { value: '#F4A261', label: 'Orange'  },
  { value: '#E76F51', label: 'Rose'    },
  { value: '#8ED1B2', label: 'Dark'    },
];

/* Icons */
const StatusIcon = () => (
  <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
    <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z" />
  </svg>
);

const PhotoIcon = () => (
  <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
    <rect x="3" y="3" width="18" height="18" rx="3" />
    <circle cx="8.5" cy="8.5" r="1.5" />
    <polyline points="21 15 16 10 5 21" />
  </svg>
);

const StoryIcon = () => (
  <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
    <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
    <polyline points="14 2 14 8 20 8" />
    <line x1="16" y1="13" x2="8" y2="13" />
    <line x1="16" y1="17" x2="8" y2="17" />
  </svg>
);

const UploadIcon = () => (
  <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
    <polyline points="16 16 12 12 8 16" />
    <line x1="12" y1="12" x2="12" y2="21" />
    <path d="M20.39 18.39A5 5 0 0 0 18 9h-1.26A8 8 0 1 0 3 16.3" />
  </svg>
);

const SendIcon = () => (
  <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
    <line x1="22" y1="2" x2="11" y2="13" />
    <polygon points="22 2 15 22 11 13 2 9 22 2" />
  </svg>
);

/* Three Options */
type Mode = 'status' | 'photo' | 'story';

export default function CreatePostPage() {
  const router = useRouter();
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const [mode, setMode] = useState<Mode>('status');

  // status
  const [text, setText] = useState('');
  const [bgColor, setBgColor] = useState(colors[0].value);
  const [fontSize, setFontSize] = useState(40);

  // photo
  const [file, setFile] = useState<File | null>(null);
  const [previewURL, setPreviewURL] = useState<string | null>(null);
  const [caption, setCaption] = useState('');

  // story
  const [storyTitle, setStoryTitle] = useState('');
  const [storyContent, setStoryContent] = useState('');

  const [loading, setLoading] = useState(false);

  const generateImage = async (): Promise<File> => {
    const canvas = canvasRef.current!;
    const ctx = canvas.getContext('2d')!;
    canvas.width = 1080;
    canvas.height = 1080;
    ctx.fillStyle = bgColor;
    ctx.fillRect(0, 0, 1080, 1080);
    ctx.fillStyle = '#ffffff';
    ctx.font = `bold ${fontSize}px sans-serif`;
    ctx.textAlign = 'center';
    const words = text.split(' ');
    let line = '';
    let y = 500;
    words.forEach((word, i) => {
      const testLine = line + word + ' ';
      if (ctx.measureText(testLine).width > 800 && i > 0) {
        ctx.fillText(line, 540, y);
        line = word + ' ';
        y += fontSize + 20; // spacing relative to font size
      } else {
        line = testLine;
      }
    });
    ctx.fillText(line, 540, y);
    return new Promise<File>((resolve) =>
      canvas.toBlob((blob) => resolve(new File([blob!], 'status.png', { type: 'image/png' })))
    );
  };

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const f = e.target.files?.[0];
    if (!f) return;
    setFile(f);
    setPreviewURL(URL.createObjectURL(f));
  };

  const handleSubmit = async () => {
    setLoading(true);
    try {
      let imageURL = '';
      if (mode === 'status') imageURL = await uploadImage(await generateImage());
      if (mode === 'photo' && file) imageURL = await uploadImage(file);

      await addDoc(collection(db, 'communityPosts'), {
        type: mode,
        imageURL: mode !== 'story' ? imageURL : '',
        text: mode === 'status' ? text : '',
        caption: mode === 'photo' ? caption : '',
        title: mode === 'story' ? storyTitle : '',
        content: mode === 'story' ? storyContent : '',
        authorId: auth.currentUser?.uid,
        authorName: 'Admin',
        status: 'pending',
        createdAt: serverTimestamp(),
      });

      router.push('/dashboard/moderation');
    } catch (err) {
      console.error(err);
      alert('Error creating post');
    }
    setLoading(false);
  };

  const tabs: { id: Mode; label: string; icon: React.ReactNode }[] = [
    { id: 'status', label: 'Post', icon: <StatusIcon /> },
    { id: 'photo',  label: 'Photo',  icon: <PhotoIcon />  },
    { id: 'story',  label: 'Text',  icon: <StoryIcon />  },
  ];

  return (
    <div className="create-post">
      {/* Page header */}
      <div className="create-post__header">
        <h1 className="create-post__title">Create Post</h1>
        <p className="create-post__subtitle">Share something with the community.</p>
      </div>

      <div className="create-post__card">
        {/* Mode switcher */}
        <div className="mode-switcher">
          {tabs.map((tab) => (
            <button
              key={tab.id}
              className={`mode-switcher__btn ${mode === tab.id ? 'mode-switcher__btn--active' : ''}`}
              onClick={() => setMode(tab.id)}
            >
              {tab.icon}
              {tab.label}
            </button>
          ))}
        </div>

        {/* Status */}
        {mode === 'status' && (
          <>
            <div className="status-preview" style={{ background: bgColor }}>
              <textarea
                className="status-preview__textarea"
                value={text}
                onChange={(e) => setText(e.target.value)}
                placeholder="What's on your mind?"
                style={{ fontSize: `${fontSize}px` }}
              />
            </div>

            <div className="controls-row">
              <div className="color-palette">
                <span className="color-palette__label">Color</span>
                {colors.map((c) => (
                  <button
                    key={c.value}
                    className={`color-swatch ${bgColor === c.value ? 'color-swatch--active' : ''}`}
                    style={{ background: c.value }}
                    title={c.label}
                    onClick={() => setBgColor(c.value)}
                  />
                ))}
              </div>

              <div className="font-size-selector">
                <label className="font-size-selector__label">Font Size</label>

                <div className="font-size-selector__wrapper">
                  <select
                    value={fontSize}
                    onChange={(e) => setFontSize(parseInt(e.target.value))}
                    className="font-size-selector__select"
                  >
                    {[40, 50, 60, 70, 80, 90, 100].map((size) => (
                      <option key={size} value={size}>
                        {size}
                      </option>
                    ))}
                  </select>
                </div>
              </div>
            </div>
          </>
        )}

        {/* Photo */}
        {mode === 'photo' && (
          <div className="photo-upload">
            {!previewURL ? (
              <label className="photo-dropzone">
                <input
                  ref={fileInputRef}
                  type="file"
                  accept="image/*"
                  onChange={handleFileChange}
                />
                <span className="photo-dropzone__icon"><UploadIcon /></span>
                <span className="photo-dropzone__text">Click to upload a photo</span>
                <span className="photo-dropzone__sub">PNG, JPG, WEBP up to 10 MB</span>
              </label>
            ) : (
              <div className="photo-preview">
                <img src={previewURL} alt="Preview" />
                <button
                  className="photo-preview__change"
                  onClick={() => fileInputRef.current?.click()}
                >
                  Change photo
                </button>
                <input
                  ref={fileInputRef}
                  type="file"
                  accept="image/*"
                  onChange={handleFileChange}
                  style={{ display: 'none' }}
                />
              </div>
            )}

            <div className="form-field">
              <label className="form-label">Caption</label>
              <input
                className="form-input"
                type="text"
                placeholder="Write a caption…"
                value={caption}
                onChange={(e) => setCaption(e.target.value)}
              />
            </div>
          </div>
        )}

        {/* Story */}
        {mode === 'story' && (
          <div className="story-form">
            <div className="form-field">
              <label className="form-label">Title</label>
              <input
                className="form-input"
                type="text"
                placeholder="Give your story a title…"
                value={storyTitle}
                onChange={(e) => setStoryTitle(e.target.value)}
              />
            </div>
            <div className="form-field">
              <label className="form-label">Text</label>
              <textarea
                className="form-textarea"
                rows={7}
                placeholder="Write your text here…"
                value={storyContent}
                onChange={(e) => setStoryContent(e.target.value)}
              />
            </div>
          </div>
        )}

        {/* Submit */}
        <button
          className="create-post__submit"
          onClick={handleSubmit}
          disabled={loading}
        >
          {loading ? (
            <>
              <span className="btn-spinner" />
              Publishing…
            </>
          ) : (
            <>
              <SendIcon />
              Publish Post
            </>
          )}
        </button>
      </div>

      <canvas ref={canvasRef} style={{ display: 'none' }} />
    </div>
  );
}