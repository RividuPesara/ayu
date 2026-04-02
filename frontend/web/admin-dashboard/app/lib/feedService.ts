import {
  collection,
  query,
  where,
  orderBy,
  onSnapshot,
  doc,
  updateDoc,
  addDoc,
  arrayUnion,
  arrayRemove,
  increment,
  serverTimestamp,
  Timestamp,
} from 'firebase/firestore';
import { db } from './firebase';

/* Post Types */
export type PostType = 'status' | 'photo' | 'story';

export interface Comment {
  id: string;
  authorId: string;
  authorName: string;
  text: string;
  createdAt: Timestamp | null;
}

export interface FeedPost {
  id: string;
  type: PostType;
  authorId: string;
  authorName: string;
  authorHandle?: string;
  authorAvatar?: string;
  // content fields
  text?: string;
  caption?: string;
  title?: string;
  content?: string;
  imageURL?: string;
  // post engagement details
  likeCount: number;
  likedBy: string[];      
  commentCount: number;
  shareCount: number;
  // metadata
  status: string;
  createdAt: Timestamp | null;
}

function mapPost(id: string, d: any): FeedPost {
  return {
    id,
    type:          d.type         ?? 'status',
    authorId:      d.authorId     ?? '',
    authorName:    d.authorName   ?? 'Anonymous',
    authorHandle:  d.authorHandle ?? '',
    authorAvatar:  d.authorAvatar ?? null,
    text:          d.text         ?? '',
    caption:       d.caption      ?? '',
    title:         d.title        ?? '',
    content:       d.content      ?? '',
    imageURL:      d.imageURL     ?? '',
    likeCount:     d.likeCount    ?? 0,
    likedBy:       d.likedBy      ?? [],
    commentCount:  d.commentCount ?? 0,
    shareCount:    d.shareCount   ?? 0,
    status:        d.status       ?? 'approved',
    createdAt:     d.createdAt    ?? null,
  };
}

/* Real-time feed (approved posts only) */
export function subscribeFeed(
  onData: (posts: FeedPost[]) => void,
  onError: (err: Error) => void
): () => void {
  const q = query(
    collection(db, 'communityPosts'),
    where('status', '==', 'approved'),
    orderBy('createdAt', 'desc')
  );

  return onSnapshot(
    q,
    (snap) => onData(snap.docs.map((d) => mapPost(d.id, d.data()))),
    onError
  );
}

/* Comments for a post */
export function subscribeComments(
  postId: string,
  onData: (comments: Comment[]) => void,
  onError: (err: Error) => void
): () => void {
  const q = query(
    collection(db, 'communityPosts', postId, 'comments'),
    orderBy('createdAt', 'asc')
  );

  return onSnapshot(
    q,
    (snap) =>
      onData(
        snap.docs.map((d) => ({
          id: d.id,
          authorId:   d.data().authorId   ?? '',
          authorName: d.data().authorName ?? 'Anonymous',
          text:       d.data().text       ?? '',
          createdAt:  d.data().createdAt  ?? null,
        }))
      ),
    onError
  );
}

/* Likes */
export async function toggleLike(postId: string, uid: string, liked: boolean) {
  const ref = doc(db, 'communityPosts', postId);
  await updateDoc(ref, {
    likedBy:   liked ? arrayRemove(uid) : arrayUnion(uid),
    likeCount: increment(liked ? -1 : 1),
  });
}

/* Add comment */
export async function addComment(
  postId: string,
  uid: string,
  authorName: string,
  text: string
) {
 
  await addDoc(collection(db, 'communityPosts', postId, 'comments'), {
    authorId: uid,
    authorName,
    text,
    createdAt: serverTimestamp(),
  });
  
  await updateDoc(doc(db, 'communityPosts', postId), {
    commentCount: increment(1),
  });
}