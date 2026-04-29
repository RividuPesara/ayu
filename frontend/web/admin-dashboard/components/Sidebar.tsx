'use client';

import React, { useState } from 'react';
import Link from 'next/link';
import { usePathname, useParams, useRouter } from 'next/navigation';
import '../styles/sidebar.css';
import Image from 'next/image';


/* Icons */
const icons = {
  dashboard: (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
      <rect x="3" y="3" width="7" height="7" rx="1" />
      <rect x="14" y="3" width="7" height="7" rx="1" />
      <rect x="14" y="14" width="7" height="7" rx="1" />
      <rect x="3" y="14" width="7" height="7" rx="1" />
    </svg>
  ),
  users: (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
      <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
      <circle cx="9" cy="7" r="4" />
    </svg>
  ),
  documents: (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
      <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
    </svg>
  ),
  community: (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
      <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z" />
    </svg>
  ),
  settings: (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
    <circle cx="12" cy="12" r="3" />
    <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06A1.65 1.65 0 0 0 15 19.4a1.65 1.65 0 0 0-1 .6 1.65 1.65 0 0 0-.33 1V21a2 2 0 1 1-4 0v-.09a1.65 1.65 0 0 0-.33-1 1.65 1.65 0 0 0-1-.6 1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.6 15a1.65 1.65 0 0 0-.6-1 1.65 1.65 0 0 0-1-.33H3a2 2 0 1 1 0-4h.09a1.65 1.65 0 0 0 1-.33 1.65 1.65 0 0 0 .6-1 1.65 1.65 0 0 0-.33-1.82l-.06-.06A2 2 0 1 1 7.13 3.6l.06.06A1.65 1.65 0 0 0 9 4.6c.38 0 .74-.14 1-.4.26-.26.4-.62.4-1V3a2 2 0 1 1 4 0v.09c0 .38.14.74.4 1 .26.26.62.4 1 .4.38 0 .74-.14 1-.4l.06-.06A2 2 0 1 1 20.4 7.13l-.06.06c-.26.26-.4.62-.4 1 0 .38.14.74.4 1 .26.26.62.4 1 .4H21a2 2 0 1 1 0 4h-.09c-.38 0-.74.14-1 .4-.26.26-.4.62-.4 1z"/>
  </svg>
  ),
  chevron: (
    <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
      <polyline points="6 9 12 15 18 9" />
    </svg>
  ),
  logout: (
    <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
      <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" />
      <polyline points="16 17 21 12 16 7" />
      <line x1="21" y1="12" x2="9" y2="12" />
    </svg>
  ),
  article: (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
    <path d="M12 20h9" />
    <path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4 12.5-12.5z" />
  </svg>
  ),
  logs: (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
    <rect x="8" y="2" width="8" height="4" rx="1" />
    <path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2" />
    <line x1="9" y1="12" x2="15" y2="12" />
    <line x1="9" y1="16" x2="15" y2="16" />
  </svg>
  )
};

/* Navigation Configuration */
const getNavItems = (uid: string) => [
  { label: 'Dashboard', href: `/user/${uid}`, icon: icons.dashboard },
  {
    label: 'Users',
    icon: icons.users,
    children: [
      { label: 'Patients', href: `/user/${uid}/patients` },
      { label: 'Doctors', href: `/user/${uid}/doctors` },
    ],
  },
  { label: 'Documents', href: `/user/${uid}/documents`, icon: icons.documents },
  {
    label: 'Community',
    icon: icons.community,
    children: [
      { label: 'Feed', href: `/user/${uid}/feed` },
      { label: 'Create a Post', href: `/user/${uid}/create-post` },
      { label: 'Moderation', href: `/user/${uid}/moderation` },
    ],
  },
  {
    label: 'Articles',
    icon: icons.article,
    children: [
      { label: 'Create Article', href: `/user/${uid}/create-article` },
      { label: 'Manage Articles', href: `/user/${uid}/manage-articles` },
    ],
  },
  { label: 'Logs', href: `/user/${uid}/logs`, icon: icons.logs },
  { label: 'Edit Profile', href: `/user/${uid}/edit-profile`, icon: icons.settings },
];


export default function Sidebar() {
  const pathname = usePathname();
  const router = useRouter();
  const params = useParams();

  const uid = params.uid as string;

  const navItems = getNavItems(uid);
  const [openGroups, setOpenGroups] = useState<string[]>([]);

  const toggleGroup = (label: string) => {
    setOpenGroups((prev) =>
      prev.includes(label) ? prev.filter((l) => l !== label) : [...prev, label]
    );
  };

  const isActive = (href: string) => pathname === href;

  return (
    <aside className="sidebar">
      {/* Brand */}
      <div className="sidebar__brand">
        <Image
          src="/assets/logo1.png"
          alt="Logo"
          width={120}
          height={40}
          className="sidebar__logo"
        />
      </div>

      {/* Navigation */}
      <nav className="sidebar__nav">
        {navItems.map((item) => {
          if (item.children) {
            const isOpen = openGroups.includes(item.label);
            const isGroupActive = item.children.some((c) => isActive(c.href));

            return (
              <React.Fragment key={item.label}>
                <button
                  className={`sidebar__nav-item ${isGroupActive ? 'sidebar__nav-item--active' : ''}`}
                  onClick={() => toggleGroup(item.label)}
                >
                  {item.icon}
                  {item.label}
                  <span className={`sidebar__nav-chevron ${isOpen ? 'sidebar__nav-chevron--open' : ''}`}>
                    {icons.chevron}
                  </span>
                </button>

                {isOpen && (
                  <div className="sidebar__sub-nav">
                    {item.children.map((child) => (
                      <Link
                        key={child.href}
                        href={child.href}
                        className={`sidebar__sub-item ${isActive(child.href) ? 'sidebar__sub-item--active' : ''}`}
                      >
                        {child.label}
                      </Link>
                    ))}
                  </div>
                )}
              </React.Fragment>
            );
          }

          return (
            <Link
              key={item.label}
              href={item.href!}
              className={`sidebar__nav-item ${isActive(item.href!) ? 'sidebar__nav-item--active' : ''}`}
            >
              {item.icon}
              {item.label}
            </Link>
          );
        })}

        <div className="sidebar__divider" />

      </nav>

      {/* Footer */}
      <div className="sidebar__footer">
        <div className="sidebar__avatar">AU</div>

        <div className="sidebar__user-info">
          <p className="sidebar__user-name">Admin User</p>
          <p className="sidebar__user-email">admin@ayu.com</p>
        </div>

        <button
          className="sidebar__logout-btn"
          onClick={() => router.push('/login')}
          title="Sign out"
        >
          {icons.logout}
        </button>
      </div>
    </aside>
  );
}