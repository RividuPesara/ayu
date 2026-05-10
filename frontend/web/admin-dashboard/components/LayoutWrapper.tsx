'use client';

import { usePathname, useParams, useRouter } from 'next/navigation';
import Sidebar from './Sidebar';
import { useCallback, useEffect, useRef, useState } from 'react';
import { auth, db } from '../app/lib/firebase';
import { onAuthStateChanged, signOut } from 'firebase/auth';
import { doc, getDoc } from 'firebase/firestore';
import '../styles/layoutWrapper.css';
import Lottie from 'lottie-react';
import loadingAnimation from '../public/assets/loading.json';

const AUTO_LOGOUT_IDLE_MS = 60 * 60 * 1000; // 60 mins
const ACTIVITY_EVENTS = ['mousemove', 'mousedown', 'keydown', 'scroll', 'touchstart'] as const;

export default function LayoutWrapper({
  children,
}: {
  children: React.ReactNode;
}) {
  const pathname = usePathname();
  const params = useParams();
  const router = useRouter();
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [isAuthorized, setIsAuthorized] = useState(false);
  const [inactivityToast, setInactivityToast] = useState(false);
  const autoLogoutTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  const isLoginPage = pathname === '/login';

  const scheduleAutoLogout = useCallback(() => {
    if (autoLogoutTimer.current) clearTimeout(autoLogoutTimer.current);
    autoLogoutTimer.current = setTimeout(async () => {
      try {
        await signOut(auth);
      } finally {
        setInactivityToast(true);
        setTimeout(() => {
          setInactivityToast(false);
          router.push('/login');
        }, 2500);
      }
    }, AUTO_LOGOUT_IDLE_MS);
  }, [router]);

  useEffect(() => {
    if (isLoginPage) return;

    scheduleAutoLogout();

    const reset = () => scheduleAutoLogout();
    ACTIVITY_EVENTS.forEach((ev) => window.addEventListener(ev, reset, { passive: true }));

    return () => {
      if (autoLogoutTimer.current) clearTimeout(autoLogoutTimer.current);
      ACTIVITY_EVENTS.forEach((ev) => window.removeEventListener(ev, reset));
    };
  }, [isLoginPage, scheduleAutoLogout]);

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, async (user) => {
      if (user) {
        try {
          const userDoc = await getDoc(doc(db, 'users', user.uid));

          if (userDoc.exists() && userDoc.data().role === 'admin') {
            setIsAuthenticated(true);

            const urlUid = params.uid as string;

            if (urlUid && urlUid !== user.uid) {
              setIsAuthorized(false);
            } else {
              setIsAuthorized(true);
            }
          } else {
            setIsAuthenticated(false);
            router.push('/login');
          }
        } catch (error) {
          console.error('Error checking admin status:', error);
          setIsAuthenticated(false);
          router.push('/login');
        }
      } else {
        setIsAuthenticated(false);

        if (!isLoginPage) {
          router.push('/login');
        }
      }

      setIsLoading(false);
    });

    return () => unsubscribe();
  }, [pathname, params.uid, router, isLoginPage]);

  if (isLoading) {
    return (
      <div className="layout-loading-screen">
        <div className="layout-loading">
          <Lottie
            animationData={loadingAnimation}
            loop
            autoplay
            className="layout-loading-animation"
          />
        </div>
      </div>
    );
  }

  if (isLoginPage) {
    return <>{children}</>;
  }

  if (!isAuthenticated || !isAuthorized) {
    return (
      <div className="layout-wrapper-center">
        <div className="layout-wrapper-card">
          <div className="layout-wrapper-code">403</div>

          <h1 className="layout-wrapper-title">Access Denied</h1>

          <p className="layout-wrapper-text">
            You do not have permission to access this resource.
          </p>

          <button
            onClick={() => router.push('/login')}
            className="layout-wrapper-btn"
          >
            Return to Login
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="layout">
      <Sidebar />
      <main className="layout__main">
        <div className="layout__content">{children}</div>
      </main>
      {inactivityToast && (
        <div style={{
          position: 'fixed', bottom: '24px', left: '50%', transform: 'translateX(-50%)',
          background: '#1A1A2E', color: '#fff', padding: '12px 24px', borderRadius: '8px',
          fontSize: '14px', zIndex: 9999, boxShadow: '0 4px 12px rgba(0,0,0,0.3)',
        }}>
          You were logged out due to inactivity.
        </div>
      )}
    </div>
  );
}