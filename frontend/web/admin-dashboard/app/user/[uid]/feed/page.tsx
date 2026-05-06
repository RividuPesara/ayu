'use client';

import { useEffect, useState, useRef } from 'react';
import Link from 'next/link';
import { auth } from '../../../lib/firebase';
import {
  fetchFeed,
  fetchComments,
  likePost,
  addComment
} from '../../../lib/feedService';
import type { Comment, FeedPost } from '../../../lib/types';
import '../../../../styles/feed.css';

/* Post time */
function timeAgo(ts: { seconds: number } | null): string {
  if (!ts) return '';
  const s = Math.floor(Date.now() / 1000 - ts.seconds);
  if (s < 60)       return 'just now';
  if (s < 3600)     return `${Math.floor(s / 60)}m ago`;
  if (s < 86400)    return `${Math.floor(s / 3600)}h ago`;
  if (s < 2592000)  return `${Math.floor(s / 86400)}d ago`;
  if (s < 31536000) return `${Math.floor(s / 2592000)} months ago`;
  return `${Math.floor(s / 31536000)} years ago`;
}

function initials(name: string) {
  return name.split(' ').map((w) => w[0]).slice(0, 2).join('').toUpperCase();
}

function fmtCount(n: number) {
  if (n >= 1000) return `${(n / 1000).toFixed(1)}k`;
  return String(n);
}

/* Icons */
const HeartIcon = ({ filled }: { filled?: boolean }) => (
  <svg width="18" height="18" viewBox="0 0 24 24"
    fill={filled ? 'currentColor' : 'none'}
    stroke="currentColor" strokeWidth="2"
    strokeLinecap="round" strokeLinejoin="round">
    <path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z" />
  </svg>
);

const CommentIcon = () => (
  <svg width="17" height="17" viewBox="0 0 24 24" fill="none"
    stroke="currentColor" strokeWidth="2"
    strokeLinecap="round" strokeLinejoin="round">
    <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z" />
  </svg>
);

const SendIcon = () => (
  <svg width="15" height="15" viewBox="0 0 24 24" fill="none"
    stroke="currentColor" strokeWidth="2.5"
    strokeLinecap="round" strokeLinejoin="round">
    <line x1="22" y1="2" x2="11" y2="13" />
    <polygon points="22 2 15 22 11 13 2 9 22 2" />
  </svg>
);

const PlusIcon = () => (
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none"
    stroke="currentColor" strokeWidth="2.5"
    strokeLinecap="round" strokeLinejoin="round">
    <line x1="12" y1="5" x2="12" y2="19" />
    <line x1="5" y1="12" x2="19" y2="12" />
  </svg>
);

const EmptyIcon = () => (
  <svg width="52" height="52" viewBox="0 0 24 24" fill="none"
    stroke="currentColor" strokeWidth="1.3"
    strokeLinecap="round" strokeLinejoin="round">
    <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z" />
  </svg>
);

/* Like Button */
function LikeButton({
  liked,
  count,
  onLike,
}: {
  liked: boolean;
  count: number;
  onLike: () => void;
}) {
  const [animating, setAnimating] = useState(false);
  const [showFloat, setShowFloat] = useState(false);

  const handleClick = () => {
    if (!liked) {
      setAnimating(true);
      setShowFloat(true);
      setTimeout(() => setAnimating(false), 450);
      setTimeout(() => setShowFloat(false), 650);
    }
    onLike();
  };

  return (
    <button
      className={`action-btn ${liked ? 'action-btn--liked' : ''}`}
      onClick={handleClick}
      aria-label={liked ? 'Unlike' : 'Like'}
    >
      <div className={`heart-wrap ${animating ? 'heart-wrap--animating' : ''}`}>
        <HeartIcon filled={liked} />

        {showFloat && <span className="like-float">+1</span>}

        {animating && (
          <div className="like-particles">
            {[1, 2, 3, 4, 5, 6].map((n) => (
              <div key={n} className={`like-particle like-particle--${n}`} />
            ))}
          </div>
        )}
      </div>
      {fmtCount(count)}
    </button>
  );
}

/* Comments Panel */
const PREVIEW_COUNT = 2;

function CommentsPanel({ postId, onCommentAdded, }: { postId: string;  onCommentAdded: () => void; }) {
  const uid = auth.currentUser?.uid ?? '';
  const userName = auth.currentUser?.displayName || 'Admin';

  const [comments, setComments] = useState<Comment[]>([]);
  const [text, setText]         = useState('');
  const [sending, setSending]   = useState(false);
  const [showAll, setShowAll]   = useState(false);
  const textareaRef             = useRef<HTMLTextAreaElement>(null);

  const loadComments = async () => {
    const data = await fetchComments(postId);
    setComments(data);
  };

  useEffect(() => {
    loadComments();
  }, [postId]);

  const handleSend = async () => {
    const trimmed = text.trim();
    if (!trimmed) return;
    setSending(true);

    try{
      await addComment(postId, userName, trimmed);
      onCommentAdded();
      setText('');
      setShowAll(true);
      await loadComments();

      textareaRef.current?.focus();
    } catch (error) {
      console.error('Error adding comment:', error);
      setSending(false);
    }
  };

  const sorted = [...comments].sort(
    (a, b) => (b.createdAt?.seconds ?? 0) - (a.createdAt?.seconds ?? 0)
  );

  const latestComments = sorted.slice(0, PREVIEW_COUNT);

  const displayed = showAll
    ? sorted
    : latestComments;

  const hidden    = comments.length - PREVIEW_COUNT;

  return (
    <div className="comments-section">
      {comments.length > 0 && (
        <div className="comment-list">
          {!showAll && hidden > 0 && (
            <button className="comments-more-btn" onClick={() => setShowAll(true)}>
              View {hidden} earlier comment{hidden > 1 ? 's' : ''}
            </button>
          )}
          {displayed.map((c) => (
            <div key={c.id} className="comment-item">
              <div className="comment-item__avatar">{initials(c.authorName)}</div>
              <div className="comment-item__bubble">
                <div className="comment-item__header">
                  <span className="comment-item__name">{c.authorName}</span>
                  <span className="comment-item__time">{timeAgo(c.createdAt)}</span>
                </div>
                <p className="comment-item__text">{c.text}</p>
              </div>
            </div>
          ))}
        </div>
      )}

      <div className="comment-input-row">
        <div className="comment-input-avatar">{initials(userName)}</div>

        <div className="comment-input-wrap">
          <textarea
            ref={textareaRef}
            className="comment-input"
            rows={1}
            placeholder="Write a comment…"
            value={text}
            onChange={(e) => setText(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault();
                handleSend();
              }
            }}
          />

          <button
            className="comment-submit-btn"
            onClick={handleSend}
            disabled={sending || !text.trim()}
            title="Post comment"
          >
            <SendIcon />
          </button>
        </div>
      </div>
    </div>
  );
}

/* Post Card */
function PostFeedCard({ post }: { post: FeedPost }) {
  const uid   = auth.currentUser?.uid ?? '';
  const liked = post.likedBy.includes(uid) ?? false;

  const [showComments, setShowComments]     = useState(false);
  const [optimisticLike, setOptimisticLike] = useState<boolean | null>(null);
  const [optimisticCount, setOptimisticCount] = useState<number | null>(null);
  const [commentCount, setCommentCount] = useState(post.commentCount ?? 0);

  const currentlyLiked = optimisticLike  ?? liked;
  const currentCount   = optimisticCount ?? post.likeCount;

  const handleLike = async () => {
    setOptimisticLike(!currentlyLiked);
    setOptimisticCount(currentCount + (currentlyLiked ? -1 : 1));
    await likePost(post.id);
  };

  const hasImage = !!post.imageURL;

  return (
    <div className="post-feed-card">
      <div className="post-feed-card__body">
        {/* Author */}
        <div className="post-feed-card__author">
          {post.authorAvatar ? (
            <img
              src={post.authorAvatar}
              alt={post.authorName}
              className="post-feed-card__avatar"
              style={{ objectFit: 'cover' }}
            />
          ) : (
            <div className="post-feed-card__avatar">{initials(post.authorName)}</div>
          )}
          <div className="post-feed-card__author-info">
            <div className="post-feed-card__name-row">
              <span className="post-feed-card__name">{post.authorName}</span>
              {post.authorHandle && (
                <span className="post-feed-card__handle">@{post.authorHandle}</span>
              )}
            </div>
            <div className="post-feed-card__time">{timeAgo(post.createdAt)}</div>
          </div>
        </div>

        {/* Content by type — image only rendered when it exists */}
        {post.type === 'status' && (
          <>
            {hasImage ? (
              <img
                src={post.imageURL}
                alt="status"
                className="post-feed-card__image post-feed-card__image--status"
              />
            ) : (
              post.text && <p className="post-feed-card__content">{post.text}</p>
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
                  className="post-feed-card__image"
                />

                {/* caption only when image exists and text is not present */}
                {post.caption && !post.text && (
                  <p className="post-feed-card__content">
                    {post.caption}
                  </p>
                )}
              </>
            ) : (
              post.text && (
                <p className="post-feed-card__content">
                  {post.text}
                </p>
              )
            )}
          </>
        )}

        {post.type === 'story' && (
          <>
            {post.title && <p className="post-feed-card__story-title">{post.title}</p>}
            {post.content && <p className="post-feed-card__content">{post.content}</p>}
          </>
        )}
      </div>

      {/* Actions */}
      <div className="post-feed-card__divider" />
      <div className="post-feed-card__actions">
        <LikeButton liked={currentlyLiked} count={currentCount} onLike={handleLike} />

        <button
          className={`action-btn ${showComments ? 'action-btn--comment-open' : ''}`}
          onClick={() => setShowComments((v) => !v)}
        >
          <CommentIcon />
          {fmtCount(commentCount)}
        </button>
      </div>

      {/* Comments */}
      {showComments && (<CommentsPanel postId={post.id} onCommentAdded={() => setCommentCount((prev) => prev + 1)}/>)}
    </div>
  );
}

/* Page */
export default function FeedPage() {
  const [posts, setPosts]     = useState<FeedPost[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError]     = useState<string | null>(null);

  const uid = auth.currentUser?.uid;

  useEffect(() => {
    const loadPosts = async () => {
      try {
        const data = await fetchFeed();

        setPosts(data);
      } catch (err: any) {
        setError(err.message);
      } finally {
        setLoading(false);
      }
    };

    loadPosts();
  }, []);

  useEffect(() => {
    let ws: WebSocket | null = null;

    const connectWS = async () => {
      const token = await auth.currentUser?.getIdToken();

      if (!token) return;

      const WS_URL = process.env.NEXT_PUBLIC_WS_URL!;
      ws = new WebSocket(`${WS_URL}/api/feed/ws?token=${token}`);

      ws.onmessage = (event) => {
        const data = JSON.parse(event.data);

        if (data.type === "like") {
          setPosts((prev) =>
            prev.map((post) =>
              post.id === data.postId
                ? {
                    ...post,
                    likeCount: data.likeCount,
                    likedBy: data.likedBy,
                  }
                : post
            )
          );
        }

        if (data.type === "comment") {
          setPosts((prev) =>
            prev.map((post) =>
              post.id === data.postId
                ? {
                    ...post,
                    commentCount: data.commentCount,
                  }
                : post
            )
          );
        }
      };
    };

    connectWS();

    return () => {
      ws?.close();
    };
  }, []);

  return (
    <div className="feed">
      <div className="feed__header">
        <div>
          <h1 className="feed__title">Community Feed</h1>
          <p className="feed__subtitle">See what the community is talking about.</p>
        </div>
        <Link
          href={`/user/${auth.currentUser?.uid}/create-post`}
          className="feed__create-btn"
        >
          <PlusIcon /> New Post
        </Link>
      </div>

      {loading ? (
        <div className="feed__list">
          <div className="feed__state">
            <div className="feed__spinner" />
            <p className="feed__state-desc">Loading posts…</p>
          </div>
        </div>
      ) : error ? (
        <div className="feed__list">
          <div className="feed__state">
            <p className="feed__state-title">Something went wrong</p>
            <p className="feed__state-desc">{error}</p>
          </div>
        </div>
      ) : posts.length === 0 ? (
        <div className="feed__list">
          <div className="feed__state">
            <EmptyIcon />
            <p className="feed__state-title">No posts yet</p>
            <p className="feed__state-desc">Be the first to share something!</p>
          </div>
        </div>
      ) : (
        <div className="feed__list">
          {posts.map((post, i) => (
            <PostFeedCard
              key={post.id}
              post={post}
            />
          ))}
        </div>
      )}
    </div>
  );
}