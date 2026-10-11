// Single source of truth for membership + posting + DM rules.
const ANY = '*';
const open = (list, v) => !list || list.length === 0 || list.includes(ANY) || list.includes(v);

function isMember(u, g) {
  if (u.role === 'admin') return true;                       // admin sees all groups
  const j = g.joinRule || {};
  if (j.excludeUsers?.includes(u.id)) return false;
  if (j.users?.includes(u.id)) return true;
  if (!j.roles || j.roles.length === 0) return false;
  return (j.roles.includes(ANY) || j.roles.includes(u.role)) &&
    open(j.depts, u.dept) && open(j.batches, u.batch) && open(j.sections, u.section);
}

function canPost(u, g) {
  if (!isMember(u, g)) return false;
  if (u.role === 'admin') return true;
  const roles = g.postRule?.roles || [];
  return roles.includes(ANY) || roles.includes(u.role);
}

function canCreateGroup(u, joinRule = {}) {
  if (u.role === 'admin') return true;
  if (u.role === 'teaching' && u.hod) {                      // HOD: own department only
    return Array.isArray(joinRule.depts) && joinRule.depts.length > 0 &&
      joinRule.depts.every(d => d === u.dept);
  }
  return false;
}

function canManageGroup(u, g) {
  if (u.role === 'admin') return true;
  return u.role === 'teaching' && u.hod && g.createdBy === u.id;
}

function canPublishAnnouncement(u, category) {
  if (u.role === 'admin') return true;
  if (category === 'event') return ['academic', 'administrative'].includes(u.role) || (u.role === 'teaching' && !!u.hod);
  if (category === 'scholarship') return ['academic', 'administrative', 'finance'].includes(u.role);
  return false;
}

const BLOCKED_PAIRS = [['student', 'cleaning'], ['student', 'security']];
const ALWAYS_PAIRS = [['security', 'admin'], ['cleaning', 'admin'], ['administrative', 'admin']];
const pair = (a, b, [x, y]) => (a === x && b === y) || (a === y && b === x);

// DM allowed if: role-pair rule OR they share a non-broadcast group.
function canDm(a, b, groups) {
  if (a.id === b.id) return false;
  if (a.role === 'admin' || b.role === 'admin') return true;
  if (BLOCKED_PAIRS.some(p => pair(a.role, b.role, p))) return false;
  if (ALWAYS_PAIRS.some(p => pair(a.role, b.role, p))) return true;
  return groups.some(g => g.type !== 'broadcast' && g.type !== 'emergency' &&
    isMember(a, g) && isMember(b, g));
}

module.exports = { ANY, isMember, canPost, canCreateGroup, canManageGroup, canPublishAnnouncement, canDm };
