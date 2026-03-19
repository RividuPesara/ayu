"use client";

import "./LoginPage.css"; // import CSS for styling

export default function LoginPage() { // Main component for the login page

  return (
    <div className="page"> 
     {/* LEFT SIDE OF THE SCREEN: Video Panel */}
      <div className="video-panel"> 
        <video 
            autoPlay 
            muted 
            loop 
            playsInline>
          <source src="/assets/login.mp4" type="video/mp4" />
        </video>
      </div>

      {/* RIGHT SIDE OF THE SCREEN: Login Panel */}
      <div className="login-panel">
          <div className="logo-section">
            <div className="logo-mark">
                {/* Logo image */}
                <img src="/assets/logo.png" alt="AYU Logo" className="logo-img" />
            </div>
          </div>

        </div>
      </div>
  );
}