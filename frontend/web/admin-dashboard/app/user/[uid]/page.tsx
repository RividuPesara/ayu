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
  BarChart,
  Bar,
  Legend,
} from 'recharts';

import { db } from '../../lib/firebase';
import { collection, getDocs } from 'firebase/firestore';

function CustomTooltip({ active, payload, label }: any) {
  if (active && payload && payload.length) {
    return (
      <div
        style={{
          background: '#1a1730',
          border: '1px solid rgba(139,92,246,0.3)',
          borderRadius: '10px',
          padding: '10px 14px',
          color: '#e2e0ff',
          fontSize: '13px',
        }}
      >
        <p style={{ color: '#a78bfa', fontWeight: 600 }}>{label}</p>
        {payload.map((p: any) => (
          <p key={p.dataKey}>
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

  const [stats, setStats] = useState<any[]>([]);
  const [rolesData, setRolesData] = useState<any[]>([]);

  /* Fetch data to display */
  useEffect(() => {
    const fetchStats = async () => {
      try {
        const patientsSnap = await getDocs(collection(db, 'patients'));
        const companionsSnap = await getDocs(collection(db, 'companions'));
        const doctorsSnap = await getDocs(collection(db, 'doctors'));

        const totalPatients = patientsSnap.size;
        const totalCompanions = companionsSnap.size;
        const totalDoctors = doctorsSnap.size;

        setStats([
          {
            label: 'Total Patients',
            value: totalPatients,
            desc: 'Registered patients',
            icon: '👤',
          },
          {
            label: 'Total Companions',
            value: totalCompanions,
            desc: 'Registered companions',
            icon: '👥',
          },
          {
            label: 'Total Doctors',
            value: totalDoctors,
            desc: 'Registered doctors',
            icon: '🩺',
          },
        ]);

        setRolesData([
          {
            name: 'Users',
            Patients: totalPatients,
            Companions: totalCompanions,
            Doctors: totalDoctors,
          },
        ]);

        setDataLoaded(true);
      } catch (error) {
        console.error('Error fetching dashboard data:', error);
      } finally {
        setLoading(false);
      }
    };

    fetchStats();
  }, []);

  const newUsersData = [
    { month: 'Jan', users: 1 },
    { month: 'Feb', users: 2 },
    { month: 'Mar', users: 1 },
    { month: 'Apr', users: 2 },
    { month: 'May', users: 3 },
    { month: 'Jun', users: 2 },
  ];

  /* Loading Screen */
  if (loading || !dataLoaded) {
    return (
      <div
        style={{
          height: '100vh',
          width: '100vw',
          display: 'flex',
          alignItems: 'left',
          justifyContent: 'left',
          paddingLeft: '240px', 
        }}
      >
        <Lottie
          animationData={loadingAnimation}
          loop
          autoplay
          style={{
            width: 700,
            height: 700,
          }}
        />
      </div>
    );
  }

  /* Dashboard */
  return (
    <div className="dashboard">
      <div className="dashboard__header">
        <h1 className="dashboard__title">Dashboard</h1>
        <p className="dashboard__subtitle">
          An overview of your platform's activity.
        </p>
      </div>

      <div className="dashboard__stats">
        {stats.map((s) => (
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

      <div className="dashboard__charts">
        <div className="chart-card">
          <h2 className="chart-card__title">New Users</h2>
          <div className="chart-card__body">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={newUsersData}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="month" />
                <YAxis allowDecimals={false} />
                <Tooltip content={<CustomTooltip />} />
                <Line
                  type="monotone"
                  dataKey="users"
                  stroke="#7c3aed"
                  strokeWidth={2.5}
                />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </div>

        <div className="chart-card">
          <h2 className="chart-card__title">User Roles</h2>
          <div className="chart-card__body">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={rolesData}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="name" />
                <YAxis allowDecimals={false} />
                <Tooltip content={<CustomTooltip />} />
                <Legend />
                <Bar dataKey="Patients" fill="#7c3aed" />
                <Bar dataKey="Companions" fill="#a78bfa" />
                <Bar dataKey="Doctors" fill="#6366f1" />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>
      </div>
    </div>
  );
}