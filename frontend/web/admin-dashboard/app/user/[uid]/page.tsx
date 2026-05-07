'use client';

import { useEffect, useState } from 'react';
import Lottie from 'lottie-react';
import loadingAnimation from '../../../public/assets/loading.json';

import '../../../styles/dashboard.css';

import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Legend,
} from 'recharts';

import { fetchDashboardData } from '../../lib/dashboardService';

function CustomTooltip({ active, payload, label }: any) {
  if (active && payload && payload.length) {
     return (
      <div className="chart-tooltip">
        <p className="chart-tooltip__label">{label}</p>

        {payload.map((p: any) => (
          <p key={p.dataKey} className="chart-tooltip__item">
            {p.name ?? p.dataKey}: <strong>{p.value}</strong>
          </p>
        ))}
      </div>
    );
  }
  return null;
}

export default function DashboardPage() {
  const [loading, setLoading] = useState(true);
  const [dataLoaded, setDataLoaded] = useState(false);
  const [dateTime, setDateTime] = useState("");

  const [stats, setStats] = useState<any[]>([]);
  const [newUsersData, setNewUsersData] = useState<any[]>([]);
  const [adminName, setAdminName] = useState('Admin');

  /* Fetch data to display */
  useEffect(() => {
    const fetchStats = async () => {
      try {
        const data = await fetchDashboardData();
        setAdminName(data.adminName || 'Admin');

        setStats([
          {
            label: 'Total Patients',
            value: data.stats.totalPatients,
            desc: 'Registered patients',
            icon: '👤',
          },
          {
            label: 'Total Companions',
            value: data.stats.totalCompanions,
            desc: 'Registered companions',
            icon: '👥',
          },
          {
            label: 'Total Doctors',
            value: data.stats.totalDoctors,
            desc: 'Registered doctors',
            icon: '🩺',
          },
          {
            label: 'Posts to Approve',
            value: data.stats.postsToApprove,
            desc: 'Pending community posts',
            icon: '📝',
          },
          {
            label: 'Documents to Review',
            value: data.stats.documentsToReview,
            desc: 'Pending donation documents',
            icon: '📄',
          },
        ]);

        setNewUsersData(data.newUsers || []);
        setDataLoaded(true);
      } catch (error) {
        console.error('Error fetching dashboard data:', error);
      } finally {
        setLoading(false);
      }
    };
    
    fetchStats();
  }, []);

  useEffect(() => {
    const updateDateTime = () => {
      const now = new Date();

      const time = now.toLocaleTimeString([], {
        hour: "2-digit",
        minute: "2-digit",
      });

      const date = now.toLocaleDateString([], {
        weekday: "short",
        month: "short",
        day: "numeric",
      });

      setDateTime(`${time} • ${date}`);
    };

    updateDateTime();
    const interval = setInterval(updateDateTime, 60000); // update every minute

    return () => clearInterval(interval);
  }, []);

  const isDashboardLoading = loading || !dataLoaded;

  /* Dashboard */
  return (
    <div className="dashboard">
      <div className="dashboard__header">
        <div>
          <h1 className="dashboard__title">Dashboard</h1>
          <p className="dashboard__subtitle">
            An overview of your platform's activity.
          </p>
        </div>

        <div className="dashboard__datetime">
          {dateTime}
        </div>
      </div>

      <div className="dashboard__hero">
        <div className="dashboard__hero-content">
          <h2>Hi{adminName && adminName !== 'Admin' ? `, ${adminName}` : ''} 👋</h2>
          <p>Welcome back. Here&apos;s what&apos;s happening in AYU.</p>
        </div>

        <div className="dashboard__hero-circle dashboard__hero-circle--one" />
        <div className="dashboard__hero-circle dashboard__hero-circle--two" />
        <div className="dashboard__hero-circle dashboard__hero-circle--three" />
      </div>

      {isDashboardLoading ? (
        <div className="dashboard__content-loader">
          <Lottie
            animationData={loadingAnimation}
            loop
            autoplay
            style={{
              width: 420,
              height: 420,
            }}
          />
        </div>
      ) : (
        <>
          <div className="dashboard__stats">
            {stats.slice(0, 3).map((s) => (
              <div key={s.label} className="stat-card">
                <div className="stat-card__top">
                  <span>{s.icon}</span>
                  <span className="stat-card__label">{s.label}</span>
                </div>
                <div className="stat-card__value">{s.value}</div>
                <div className="stat-card__desc">{s.desc}</div>
              </div>
            ))}
          </div>

          <div className="dashboard__second-row">
            <div className="chart-card dashboard__new-users-card">
              <h2 className="chart-card__title">New Users</h2>

              <div className="chart-card__body">
                <ResponsiveContainer width="100%" height="100%">
                  <LineChart data={newUsersData}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="date" />
                    <YAxis allowDecimals={false} />
                    <Tooltip content={<CustomTooltip />} />
                    <Legend />

                    <Line
                      type="monotone"
                      dataKey="Patients"
                      stroke="#7c3aed"
                      strokeWidth={2.5}
                    />

                    <Line
                      type="monotone"
                      dataKey="Companions"
                      stroke="#a78bfa"
                      strokeWidth={2.5}
                    />

                    <Line
                      type="monotone"
                      dataKey="Doctors"
                      stroke="#4b3425"
                      strokeWidth={2.5}
                    />
                  </LineChart>
                </ResponsiveContainer>
              </div>
            </div>

            <div className="dashboard__side-cards">
              {stats.slice(3).map((s) => (
                <div key={s.label} className="stat-card stat-card--alert">
                  <div className="stat-card__top">
                    <span>{s.icon}</span>
                    <span className="stat-card__label">{s.label}</span>
                  </div>

                  <div className="stat-card__value">{s.value}</div>
                  <div className="stat-card__desc">{s.desc}</div>
                </div>
              ))}
            </div>
          </div>
        </>
      )}
    </div>
  );
}