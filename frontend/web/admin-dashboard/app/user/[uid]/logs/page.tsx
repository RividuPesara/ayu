'use client';

import { useEffect, useState } from 'react';
import '../../../../styles/patient.css';
import '../../../../styles/logs.css';
import {
  fetchAccountLogs,
  LogUser,
  UserType,
} from '../../../lib/accountLogsService';

const typeClasses: Record<UserType, string> = {
  Patient: 'type-badge type-patient',
  Companion: 'type-badge type-companion',
  Doctor: 'type-badge type-doctor',
  Admin: 'type-badge type-admin',
};

const UserIcon = () => (
  <svg viewBox="0 0 24 24" fill="currentColor">
    <path d="M12 12c2.7 0 4.8-2.1 4.8-4.8S14.7 2.4 12 2.4 7.2 4.5 7.2 7.2 9.3 12 12 12zm0 2.4c-3.2 0-9.6 1.6-9.6 4.8v2.4h19.2v-2.4c0-3.2-6.4-4.8-9.6-4.8z" />
  </svg>
);

const SearchIcon = () => (
  <svg
    width="16"
    height="16"
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    strokeWidth="2.5"
    strokeLinecap="round"
    strokeLinejoin="round"
  >
    <circle cx="11" cy="11" r="8" />
    <line x1="21" y1="21" x2="16.65" y2="16.65" />
  </svg>
);

export default function AccountLogsPage() {
  const [search, setSearch] = useState('');
  const [typeFilter, setTypeFilter] = useState('All');
  const [users, setUsers] = useState<LogUser[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [open, setOpen] = useState(false);

  useEffect(() => {
    async function loadLogs() {
      try {
        const data = await fetchAccountLogs();
        setUsers(data);
      } catch (err) {
        setError(
          err instanceof Error ? err.message : 'Failed to load account logs'
        );
      } finally {
        setLoading(false);
      }
    }

    loadLogs();
  }, []);

  const filteredUsers = users.filter((user) => {
    const matchesSearch =
      user.name.toLowerCase().includes(search.toLowerCase()) ||
      user.email.toLowerCase().includes(search.toLowerCase()) ||
      user.type.toLowerCase().includes(search.toLowerCase());

    const matchesType =
      typeFilter === 'All' || user.type === typeFilter;

    return matchesSearch && matchesType;
  });

  return (
    <div>
      <div className="page-header">
        <div className="title-section">
          <h1 className="page-title">User Account Logs</h1>
          <p className="page-subtitle">
            View user account creation and last login dates
          </p>
        </div>

        <div style={{ display: 'flex', gap: '12px', alignItems: 'center' }}>
          
          <div className="custom-dropdown">
            <div
                className="dropdown-selected"
                onClick={() => setOpen(!open)}
            >
                {typeFilter}
            </div>

            {open && (
                <div className="dropdown-menu">
                {['All', 'Patient', 'Companion', 'Doctor', 'Admin'].map((type) => (
                    <div
                    key={type}
                    className="dropdown-item"
                    onClick={() => {
                        setTypeFilter(type);
                        setOpen(false);
                    }}
                    >
                    {type}
                    </div>
                ))}
                </div>
            )}
            </div>

          <div className="search-wrapper">
            <span className="search-icon">
              <SearchIcon />
            </span>
            <input
              type="text"
              className="search-input"
              placeholder="Search users..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>

        </div>
      </div>

      {loading ? (
        <div className="patient-page-loader">
            <div className="patient-page-loader__spinner" />
            <p className="patient-page-loader__text">Loading account logs</p>
        </div>
        ) : error ? (
        <div className="empty-state">{error}</div>
        ) : (
        <div className="table-wrapper">
            <div className="table-header logs-grid">
            <span className="table-header-cell">User&apos;s Name</span>
            <span className="table-header-cell">User Type</span>
            <span className="table-header-cell">Account Creation Date</span>
            <span className="table-header-cell">Last Logged On Date</span>
            </div>

            {filteredUsers.length === 0 ? (
            <div className="empty-state">No users match your search.</div>
            ) : (
            filteredUsers.map((user) => (
                <div key={user.id} className="table-row logs-grid">
                <div className="patient-cell">
                    <div className="patient-avatar">
                    {user.avatar ? (
                        <img src={user.avatar} alt={user.name} />
                    ) : (
                        <UserIcon />
                    )}
                    </div>

                    <div>
                    <p className="patient-name">{user.name}</p>
                    <p className="patient-email">{user.email}</p>
                    </div>
                </div>

                <div>
                    <span className={typeClasses[user.type]}>
                    {user.type}
                    </span>
                </div>

                <div className="log-text">{user.createdAt}</div>
                <div className="log-text">{user.lastLogin}</div>
                </div>
            ))
            )}
        </div>
      )}
    </div>
  )
}
