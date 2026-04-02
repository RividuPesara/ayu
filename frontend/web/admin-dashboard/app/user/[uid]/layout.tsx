import { Geist, Geist_Mono } from "next/font/google";
import "../../globals.css";
import LayoutWrapper from '../../../components/LayoutWrapper';
import '../../../styles/layout.css';

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export default function UserLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <LayoutWrapper>
      {children}
    </LayoutWrapper>
  );
}