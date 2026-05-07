import LayoutWrapper from '../../../components/LayoutWrapper';

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