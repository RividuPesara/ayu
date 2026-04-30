'use client';

import { usePathname, useParams, useRouter } from 'next/navigation';
import Sidebar from './Sidebar';
import { useEffect, useState } from 'react';
import { auth, db } from '../app/lib/firebase';
import { onAuthStateChanged } from 'firebase/auth';
import { doc, getDoc } from 'firebase/firestore';
import '../styles/layoutWrapper.css';
import Lottie from 'lottie-react';
import loadingAnimation from '../public/assets/loading.json';

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

  const isLoginPage = pathname === '/login';

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
    </div>
  );
}