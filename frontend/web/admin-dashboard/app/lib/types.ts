export type PostType = 'status' | 'photo' | 'story';

export interface Comment {
  id: string;
  authorId: string;
  authorName: string;
  text: string;
  createdAt: { seconds: number } | null;
  authorAvatar?: string; 
}

export interface FeedPost {
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

  likeCount: number;
  likedBy: string[];
  commentCount: number;
  shareCount: number;

  status: string;
  createdAt: { seconds: number } | null;
}