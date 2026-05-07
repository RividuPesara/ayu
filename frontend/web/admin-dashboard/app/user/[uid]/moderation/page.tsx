'use client';

import { useEffect, useState, useTransition } from 'react';
import {
  CommunityPost,
  PostStatus,
  subscribeToPosts,
  approvePost,
  rejectPost,
} from '../../../lib/postsService';
import '../../../../styles/moderation.css';

/* Post time */
function timeAgo(ts: { seconds: number } | null): string {
  if (!ts) return '';
  const seconds = Math.floor(Date.now() / 1000 - ts.seconds);
  if (seconds < 60) return 'just now';
  if (seconds < 3600) return `${Math.floor(seconds / 60)} minutes ago`;
  if (seconds < 86400) return `${Math.floor(seconds / 3600)} hours ago`;
  if (seconds < 2592000) return `${Math.floor(seconds / 86400)} days ago`;
  if (seconds < 31536000) return `${Math.floor(seconds / 2592000)} months ago`;
  return `${Math.floor(seconds / 31536000)} years ago`;
}

function initials(name: string): string {
  return name
    .split(' ')
    .map((w) => w[0])
    .slice(0, 2)
    .join('')
    .toUpperCase();
}

// Helper to check if a post has an image
function hasImage(post: CommunityPost) {
  return !!post.imageURL?.trim();
}

/* Icons */
const CheckIcon = () => (
  <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.8" strokeLinecap="round" strokeLinejoin="round">
    <polyline points="20 6 9 17 4 12" />
  </svg>
);

const XIcon = () => (
  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.8" strokeLinecap="round" strokeLinejoin="round">
    <line x1="18" y1="6" x2="6" y2="18" />
    <line x1="6" y1="6" x2="18" y2="18" />
  </svg>
);

const EmptyIcon = () => (
  <svg width="56" height="56" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round" strokeLinejoin="round">
    <circle cx="12" cy="12" r="10" />
    <line x1="4.93" y1="4.93" x2="19.07" y2="19.07" />
  </svg>
);

const AlertIcon = () => (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <circle cx="12" cy="12" r="10" />
    <line x1="12" y1="8" x2="12" y2="12" />
    <line x1="12" y1="16" x2="12.01" y2="16" />
  </svg>
);

/* Tabs */
type FilterTab = { label: string; value: PostStatus | null };
const TABS: FilterTab[] = [
  { label: 'Pending', value: 'pending' },
  { label: 'Approved', value: 'approved' },
  { label: 'Rejected', value: 'rejected' },
  { label: 'All', value: null },
];

/* Post Card */
function PostCard({ post }: { post: CommunityPost }) {
  const [isPending, startTransition] = useTransition();
  const [actionDone, setActionDone] = useState(false);

  const handleApprove = () => {
    startTransition(async () => {
      await approvePost(post.id);
      setActionDone(true);
    });
  };

  const handleReject = () => {
    startTransition(async () => {
      await rejectPost(post.id);
      setActionDone(true);
    });
  };

  // check if a post has an image
  const hasImage = post?.imageURL?.trim();

  return (
    <div className="post-card">
      <div className={`post-card__status post-card__status--${post.status}`}>
        {post.status}
      </div>
      {/* Author */}
      <div className="post-card__author">
        {post?.authorAvatar ? (
          <img
            src={post.authorAvatar}
            alt={post.authorName ?? 'Anonymous'}
            className="post-card__avatar"
            style={{ objectFit: 'cover' }}
          />
        ) : (
          <div className="post-card__avatar">
            {(post?.authorName ?? '??')
              .split(' ')
              .map((w) => w[0])
              .slice(0, 2)
              .join('')
              .toUpperCase()}
          </div>
        )}
        <div className="post-card__author-info">
          <div className="post-card__name-row">
            <span className="post-card__name">{post?.authorName ?? 'Anonymous'}</span>
            {post?.authorHandle && <span className="post-card__handle">@{post.authorHandle}</span>}
          </div>
          <div className="post-card__time">
            {post?.createdAt ? timeAgo(post.createdAt) : ''}
          </div>
        </div>
      </div>

      {/* Content */}
      <div className="post-card__body">
                {post.type === 'status' && (
          <>
            {hasImage ? (
              <img
                src={post.imageURL}
                alt="status"
                className="post-card__image post-card__image--status"
              />
            ) : (
              post.text && <p className="post-card__content">{post.text}</p>
            )}
          </>
        )}

        {post.type === 'photo' && (
          <>
            {hasImage ? (
              <>
                <img
                  src={post.imageURL}
                  alt="post"
                  className="post-card__image"
                />

                {/* caption only when image exists and text is not present */}
                {post.caption && !post.text && (
                  <p className="post-card__content">
                    {post.caption}
                  </p>
                )}
              </>
            ) : (
              post.text && (
                <p className="post-card__content">
                  {post.text}
                </p>
              )
            )}
          </>
        )}

        {post?.type === 'story' && (
          <>
            {post?.title && <p className="post-card__story-title"><strong>{post.title}</strong></p>}
            {post?.content && <p className="post-card__content">{post.content}</p>}
          </>
        )}
      </div>

      {/* Actions */}
      {post?.status === 'pending' && (
        <div className="post-card__actions">
          <button
            className={`post-card__btn post-card__btn--reject ${
              isPending || actionDone ? 'post-card__btn--disabled' : ''
            }`}
            onClick={handleReject}
            disabled={isPending || actionDone}
          >
            <XIcon /> Reject
          </button>
          <button
            className={`post-card__btn post-card__btn--approve ${
              isPending || actionDone ? 'post-card__btn--disabled' : ''
            }`}
            onClick={handleApprove}
            disabled={isPending || actionDone}
          >
            <CheckIcon /> Approve
          </button>
        </div>
      )}
    </div>
  );
}

/* Moderation Page */
export default function ModerationPage() {
  const [activeTab, setActiveTab] = useState<PostStatus | null>('pending');
  const [posts, setPosts] = useState<CommunityPost[]>([]);
  const [pendingCount, setPendingCount] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    setLoading(true);
    setError(null);

    const unsub = subscribeToPosts(
      activeTab,
      (data) => {
        setPosts(data);
        setLoading(false);
      },
      (err) => {
        setError(err.message);
        setLoading(false);
      }
    );

    return unsub;
  }, [activeTab]);

  // Live count of pending posts for badge
  useEffect(() => {
    const unsub = subscribeToPosts(
      'pending',
      (data) => setPendingCount(data.length),
      () => {}
    );
    return unsub;
  }, []);

  return (
    <div className="moderation">
      {/* Header */}
      <div className="moderation__header">
        <h1 className="moderation__title">Community Moderation</h1>
        <p className="moderation__subtitle">Review and approve posts from the community.</p>
      </div>

      {/* Filter tabs */}
      <div className="moderation__filters">
        {TABS.map((tab) => (
          <button
            key={String(tab.value)}
            className={`moderation__filter-btn ${activeTab === tab.value ? 'moderation__filter-btn--active' : ''}`}
            onClick={() => setActiveTab(tab.value)}
          >
            {tab.label}
            {tab.value === 'pending' && pendingCount > 0 && (
              <span className="moderation__count-badge">{pendingCount}</span>
            )}
          </button>
        ))}
      </div>

      {/* Error */}
      {error && (
        <div className="moderation__error">
          <AlertIcon />
          <span>Failed to load posts: {error}</span>
        </div>
      )}

      {/* Content */}
      {loading ? (
        <div className="moderation__state">
          <div className="spinner" />
          <p className="moderation__state-desc">Loading posts…</p>
        </div>
      ) : posts.length === 0 ? (
        <div className="moderation__state">
          <span className="moderation__state-icon"><EmptyIcon /></span>
          <p className="moderation__state-title">No posts here</p>
          <p className="moderation__state-desc">
            {activeTab === 'pending'
              ? 'There are no posts awaiting review.'
              : `No ${activeTab ?? ''} posts found.`}
          </p>
        </div>
      ) : (
        <div className="moderation__list">
          {posts.map((post) => (
            <PostCard key={post.id} post={post} />
          ))}
        </div>
      )}
    </div>
  );
}