import {
  collection,
  query,
  where,
  orderBy,
  onSnapshot,
  doc,
  updateDoc,
  serverTimestamp,
  Timestamp,
  QuerySnapshot,
  DocumentData,
} from 'firebase/firestore';
import { db } from './firebase'; 

/* Post Types */
export type PostType = 'status' | 'photo' | 'story';

export type PostStatus = 'pending' | 'approved' | 'rejected';

export type CommunityPost = {
  id: string;
  type: PostType;
  authorId: string;
  authorName: string;
  authorHandle?: string;
  authorAvatar?: string;

  text?: string;
  caption?: string;
  title?: string;
  content?: string;
  imageURL?: string;


  status: string;
  createdAt: Timestamp | null;
};

function mapDoc(doc: DocumentData & { id: string }): CommunityPost {
  const d = doc.data();
  return {
    id: doc.id,
    type: d.type ?? 'status',
    authorId: d.authorId ?? '',
    authorName: d.authorName ?? 'Anonymous',
    authorHandle: d.authorHandle ?? '',
    authorAvatar: d.authorAvatar ?? undefined,
    text: d.text ?? '',
    caption: d.caption ?? '',  
    title: d.title ?? '',
    content: d.content ?? '',
    imageURL: d.imageURL ?? '',
    status: d.status ?? 'pending',
    createdAt: d.createdAt ?? null,
  };
}

export function subscribeToPosts(
  status: PostStatus | null,
  onData: (posts: CommunityPost[]) => void,
  onError: (err: Error) => void
): () => void {
  const postsRef = collection(db, 'communityPosts');

  const q =
    status !== null
      ? query(
          postsRef,
          where('status', '==', status),
          orderBy('createdAt', 'desc')
        )
      : query(postsRef, orderBy('createdAt', 'desc'));

  return onSnapshot(
    q,
    (snapshot: QuerySnapshot<DocumentData>) => {
      const posts = snapshot.docs.map((d) =>
        mapDoc({ id: d.id, data: () => d.data() } as any)
      );
      onData(posts);
    },
    onError
  );
}

/* Mutations */
export async function approvePost(postId: string): Promise<void> {
  await updateDoc(doc(db, 'communityPosts', postId), {
    status: 'approved',
    moderatedAt: serverTimestamp(),
  });
}

export async function rejectPost(postId: string): Promise<void> {
  await updateDoc(doc(db, 'communityPosts', postId), {
    status: 'rejected',
    moderatedAt: serverTimestamp(),
  });
}