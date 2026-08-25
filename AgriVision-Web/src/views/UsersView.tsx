import React, { useEffect, useState } from 'react';
import { useAuth } from '../core/auth/AuthContext';
import { HttpClient } from '../core/api/http';
import type { UserRole } from '../core/rbac/roles';
import { GlassCard } from '../components/ui/GlassCard';
import { MetricBadge } from '../components/ui/MetricBadge';
import { Users, Mail, UserPlus, ShieldAlert, Trash2, AlertTriangle, ChevronDown, ChevronUp, ArrowRightLeft } from 'lucide-react';
import clsx from 'clsx';

import type { Field } from '../core/types';

interface Invite {
  id: string;
  email: string;
  role: string;
  status: string;
  created_at: string;
}

interface UserProfileData {
  id: string;
  email: string;
  role: string;
  created_at: string;
}

export const UsersView: React.FC = () => {
  const { sendInviteLink, user } = useAuth();
  const [invites, setInvites] = useState<Invite[]>([]);
  const [users, setUsers] = useState<UserProfileData[]>([]);
  const [fields, setFields] = useState<Field[]>([]);
  const [expandedUser, setExpandedUser] = useState<string | null>(null);
  const [transferState, setTransferState] = useState<{fieldId: string, newOwnerId: string} | null>(null);
  
  const [loading, setLoading] = useState(false);
  const [activeTab, setActiveTab] = useState<'invites' | 'users'>('invites');
  
  const [newEmail, setNewEmail] = useState('');
  const [newRole, setNewRole] = useState<UserRole>('agronomist');
  const [inviteStatus, setInviteStatus] = useState<{type: 'success' | 'error', msg: string} | null>(null);

  const fetchData = async () => {
    try {
      const http = new HttpClient();
      const invitesData = await http.get<Invite[]>('/api/invitations');
      setInvites(invitesData);

      if (user?.role === 'admin') {
        const [usersData, fieldsData] = await Promise.all([
          http.get<UserProfileData[]>('/api/admin/users').catch(() => []),
          http.get<Field[]>('/api/fields?admin_view=true').catch(() => [])
        ]);
        setUsers(usersData);
        setFields(fieldsData);
      }
    } catch (e) {
      console.error("Failed to fetch admin data", e);
    }
  };

  useEffect(() => {
    fetchData();
  }, [user]);

  const handleDeleteUser = async (id: string) => {
    if (!window.confirm("Are you sure you want to delete this user and ALL of their associated fields? This action is permanent and cannot be undone.")) return;
    try {
      const http = new HttpClient();
      await http.delete(`/api/admin/users/${id}`);
      fetchData();
    } catch (e: any) {
      alert("Failed to delete user: " + (e.message || "Unknown error"));
    }
  };

  const handleDeleteField = async (id: string) => {
    if (!window.confirm("Are you sure you want to permanently delete this field?")) return;
    try {
      const http = new HttpClient();
      await http.delete(`/api/fields/${id}`);
      fetchData();
    } catch (e: any) {
      alert("Failed to delete field: " + (e.message || "Unknown error"));
    }
  };

  const handleTransferField = async (fieldId: string) => {
    if (!transferState || transferState.fieldId !== fieldId || !transferState.newOwnerId) return;
    if (!window.confirm("Are you sure you want to transfer ownership of this field?")) return;
    try {
      const http = new HttpClient();
      await http.post(`/api/admin/fields/${fieldId}/transfer`, { new_owner_id: transferState.newOwnerId });
      setTransferState(null);
      fetchData();
    } catch (e: any) {
      alert("Failed to transfer field: " + (e.message || "Unknown error"));
    }
  };

  const handleInvite = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setInviteStatus(null);
    try {
      const http = new HttpClient();
      await http.post('/api/invitations', { email: newEmail, role: newRole });
      await sendInviteLink(newEmail);
      setInviteStatus({ type: 'success', msg: `Invitation sent to ${newEmail}` });
      setNewEmail('');
      fetchData();
    } catch (e: any) {
      setInviteStatus({ type: 'error', msg: e.message || 'Failed to send invite' });
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex flex-col gap-6 pb-10 max-w-5xl mx-auto">
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 rounded-lg bg-primary-medium/20 border border-primary-light flex items-center justify-center">
          <Users size={20} className="text-accent-lime" />
        </div>
        <div>
          <h2 className="text-[22px] font-extrabold text-text-main">User Management</h2>
          <p className="text-[13px] text-text-muted mt-0.5">Invite and manage platform staff and administrators.</p>
        </div>
      </div>

      {user?.role !== 'admin' ? (
        <GlassCard className="p-8 text-center border-red-500/20 bg-red-500/5 mt-4">
          <ShieldAlert size={40} className="mx-auto text-red-400 mb-4" />
          <h3 className="text-xl font-bold text-white mb-2">Access Denied</h3>
          <p className="text-text-muted text-sm">You must be a Platform Administrator to invite users, view registered accounts, or delete records.</p>
        </GlassCard>
      ) : (
        <>
          <GlassCard className="p-6">
            <div className="flex items-center gap-2 mb-4">
              <UserPlus size={18} className="text-primary-light" />
              <h3 className="text-base font-bold text-text-main">Invite New User</h3>
            </div>
            
            <form onSubmit={handleInvite} className="flex flex-col md:flex-row gap-4 items-start">
          <div className="flex-1 w-full">
            <label className="block text-[11px] font-semibold text-text-muted mb-1.5">Email Address</label>
            <div className="relative">
              <Mail size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-text-dim" />
              <input 
                type="email" 
                required 
                value={newEmail}
                onChange={(e) => setNewEmail(e.target.value)}
                className="w-full pl-10 pr-3.5 py-2.5 rounded-sm bg-black/30 border border-border-glass text-white text-sm outline-none focus:border-primary-light transition-colors"
                placeholder="user@agrivision.ai"
              />
            </div>
          </div>
          
          <div className="w-full md:w-[200px] shrink-0">
            <label className="block text-[11px] font-semibold text-text-muted mb-1.5">Role</label>
            <select 
              value={newRole}
              onChange={(e) => setNewRole(e.target.value as UserRole)}
              className="w-full px-3.5 py-2.5 rounded-sm bg-black/30 border border-border-glass text-white text-sm outline-none focus:border-primary-light transition-colors appearance-none cursor-pointer"
            >
              <option value="agronomist">Agronomist</option>
              <option value="admin">Platform Admin</option>
            </select>
          </div>
          
          <div className="pt-6 w-full md:w-auto">
            <button 
              type="submit" 
              disabled={loading} 
              className="btn-primary w-full md:w-auto h-10 px-6 justify-center"
            >
              {loading ? 'Sending...' : 'Send Invite'}
            </button>
          </div>
        </form>

        {inviteStatus && (
          <div className={clsx(
            "mt-4 p-3 rounded-md text-[13px] flex items-center gap-2 border",
            inviteStatus.type === 'success' 
              ? "bg-accent-lime/10 border-accent-lime/30 text-accent-lime" 
              : "bg-red-400/10 border-red-400/30 text-red-400"
          )}>
            {inviteStatus.type === 'error' && <ShieldAlert size={16} />}
            {inviteStatus.msg}
          </div>
        )}
      </GlassCard>

      {user?.role === 'admin' && (
        <div className="flex gap-2 border-b border-white/10 pb-1 mb-2">
          <button 
            onClick={() => setActiveTab('invites')}
            className={clsx("px-4 py-2 text-sm font-semibold rounded-t-md transition-colors", activeTab === 'invites' ? "bg-white/10 text-white border-b-2 border-primary-light" : "text-text-muted hover:text-white")}
          >
            Sent Invitations
          </button>
          <button 
            onClick={() => setActiveTab('users')}
            className={clsx("px-4 py-2 text-sm font-semibold rounded-t-md transition-colors", activeTab === 'users' ? "bg-white/10 text-white border-b-2 border-primary-light" : "text-text-muted hover:text-white")}
          >
            Registered Users & Fields
          </button>
        </div>
      )}

      {activeTab === 'invites' && (
        <GlassCard className="p-0 overflow-hidden">
          <div className="p-5 border-b border-border-glass bg-white/5">
            <h3 className="text-base font-bold text-text-main">Sent Invitations</h3>
          </div>
          
          <div className="overflow-x-auto">
            <table className="w-full border-collapse text-left text-[13px]">
              <thead>
                <tr className="border-b border-border-glass text-text-muted">
                  <th className="p-4 font-semibold">Email</th>
                  <th className="p-4 font-semibold">Role</th>
                  <th className="p-4 font-semibold">Status</th>
                  <th className="p-4 font-semibold">Date</th>
                </tr>
              </thead>
              <tbody>
                {invites.map((inv) => (
                  <tr key={inv.id} className="border-b border-white/5 transition-colors hover:bg-white/5">
                    <td className="p-4 font-semibold text-text-main">{inv.email}</td>
                    <td className="p-4 font-semibold text-primary-light capitalize">{inv.role.replace('_', ' ')}</td>
                    <td className="p-4">
                      <MetricBadge 
                        label={inv.status} 
                        variant={inv.status === 'accepted' ? 'success' : 'warning'} 
                        size="sm" 
                      />
                    </td>
                    <td className="p-4 text-text-muted">
                      {new Date(inv.created_at).toLocaleDateString()}
                    </td>
                  </tr>
                ))}
                {invites.length === 0 && (
                  <tr>
                    <td colSpan={4} className="p-8 text-center text-text-dim text-sm italic">
                      No invitations sent yet.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </GlassCard>
      )}

      {activeTab === 'users' && user?.role === 'admin' && (
        <GlassCard className="p-0 overflow-hidden border-red-500/20">
          <div className="p-5 border-b border-border-glass bg-red-500/5 flex items-center gap-2">
            <AlertTriangle size={18} className="text-red-400" />
            <h3 className="text-base font-bold text-text-main">Registered Users & Field Management</h3>
            <span className="text-xs text-text-muted ml-auto">Admin Zone</span>
          </div>
          
          <div className="overflow-x-auto">
            <table className="w-full border-collapse text-left text-[13px]">
              <thead>
                <tr className="border-b border-border-glass text-text-muted bg-black/20">
                  <th className="p-4 font-semibold w-10"></th>
                  <th className="p-4 font-semibold">Email</th>
                  <th className="p-4 font-semibold">Role</th>
                  <th className="p-4 font-semibold">Joined Date</th>
                  <th className="p-4 font-semibold">Fields Owned</th>
                  <th className="p-4 font-semibold text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                {users.map((u) => {
                  const userFields = fields.filter(f => (f as any).owner_id === u.id);
                  const isExpanded = expandedUser === u.id;
                  return (
                    <React.Fragment key={u.id}>
                      <tr className={clsx("border-b border-white/5 transition-colors hover:bg-white/5 group", isExpanded && "bg-white/5")}>
                        <td className="p-4">
                          <button 
                            onClick={() => setExpandedUser(isExpanded ? null : u.id)}
                            className="p-1 text-text-muted hover:text-white rounded transition-colors"
                          >
                            {isExpanded ? <ChevronUp size={16} /> : <ChevronDown size={16} />}
                          </button>
                        </td>
                        <td className="p-4 font-semibold text-text-main">{u.email}</td>
                        <td className="p-4 font-semibold text-primary-light capitalize">{u.role.replace('_', ' ')}</td>
                        <td className="p-4 text-text-muted">
                          {new Date(u.created_at).toLocaleDateString()}
                        </td>
                        <td className="p-4 text-text-muted">
                          <MetricBadge label={`${userFields.length} Fields`} variant="neutral" size="sm" />
                        </td>
                        <td className="p-4 text-right">
                          {u.id !== user.uid ? (
                            <button 
                              onClick={() => handleDeleteUser(u.id)}
                              className="opacity-0 group-hover:opacity-100 p-1.5 text-text-dim hover:text-red-400 hover:bg-red-400/10 rounded transition-all"
                              title="Delete User"
                            >
                              <Trash2 size={16} />
                            </button>
                          ) : (
                            <span className="text-text-dim text-xs">Current User</span>
                          )}
                        </td>
                      </tr>
                      {isExpanded && (
                        <tr className="bg-black/40 border-b border-white/5">
                          <td colSpan={6} className="p-6">
                            <div className="bg-background-dark/50 rounded-lg border border-white/5 overflow-hidden">
                              <div className="p-3 border-b border-white/5 bg-white/5 flex items-center justify-between">
                                <h4 className="font-bold text-[13px] text-text-main flex items-center gap-2">
                                  Fields owned by {u.email}
                                </h4>
                              </div>
                              {userFields.length > 0 ? (
                                <table className="w-full border-collapse text-left text-[12px]">
                                  <thead>
                                    <tr className="border-b border-white/5 text-text-muted">
                                      <th className="p-3 font-semibold">Field Name</th>
                                      <th className="p-3 font-semibold">Crop</th>
                                      <th className="p-3 font-semibold">Area (ha)</th>
                                      <th className="p-3 font-semibold text-right">Manage Field</th>
                                    </tr>
                                  </thead>
                                  <tbody>
                                    {userFields.map(f => (
                                      <tr key={f.id} className="border-b border-white/5 last:border-0 hover:bg-white/5 transition-colors">
                                        <td className="p-3 text-white font-medium">{f.name}</td>
                                        <td className="p-3 text-text-muted capitalize">{f.crop_type?.replace('_', ' ') || 'N/A'}</td>
                                        <td className="p-3 text-text-muted">{f.area_ha?.toFixed(2)}</td>
                                        <td className="p-3 text-right">
                                          <div className="flex items-center justify-end gap-3">
                                            <div className="flex items-center gap-2 bg-black/40 rounded p-1">
                                              <select 
                                                className="bg-transparent text-text-muted text-[11px] outline-none cursor-pointer max-w-[120px]"
                                                value={transferState?.fieldId === f.id ? transferState.newOwnerId : ""}
                                                onChange={(e) => setTransferState({fieldId: f.id, newOwnerId: e.target.value})}
                                              >
                                                <option value="" disabled>Transfer to...</option>
                                                {users.filter(other => other.id !== u.id).map(other => (
                                                  <option key={other.id} value={other.id}>{other.email}</option>
                                                ))}
                                              </select>
                                              <button
                                                onClick={() => handleTransferField(f.id)}
                                                disabled={transferState?.fieldId !== f.id || !transferState?.newOwnerId}
                                                className="p-1 text-primary-light hover:text-primary disabled:opacity-50 transition-colors"
                                                title="Confirm Transfer"
                                              >
                                                <ArrowRightLeft size={14} />
                                              </button>
                                            </div>
                                            
                                            <button 
                                              onClick={() => handleDeleteField(f.id)}
                                              className="p-1.5 text-text-dim hover:text-red-400 hover:bg-red-400/10 rounded transition-all"
                                              title="Delete Field"
                                            >
                                              <Trash2 size={15} />
                                            </button>
                                          </div>
                                        </td>
                                      </tr>
                                    ))}
                                  </tbody>
                                </table>
                              ) : (
                                <div className="p-6 text-center text-text-dim text-sm italic">
                                  This user has no fields.
                                </div>
                              )}
                            </div>
                          </td>
                        </tr>
                      )}
                    </React.Fragment>
                  );
                })}
                {users.length === 0 && (
                  <tr>
                    <td colSpan={6} className="p-8 text-center text-text-dim text-sm italic">
                      No users found.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </GlassCard>
      )}
      </>
      )}
    </div>
  );
};
