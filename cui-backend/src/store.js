// In-memory store + seed data. Swap for MongoDB later; keep the same function names.
const { ANY } = require('./rules');
const DEPTS = ['CS', 'EE', 'Management Sciences'];

const users = [
  { id: 'u_admin', name: 'System Admin', role: 'admin', dept: 'IT' },
  { id: 'u_reg', name: 'Registrar Office', role: 'administrative', dept: 'Administration' },
  { id: 'u_fin', name: 'Ms. Ayesha (Finance)', role: 'finance', dept: 'Finance' },
  { id: 'u_acad', name: 'Mr. Imran (Academic Office)', role: 'academic', dept: 'Academic' },
  { id: 'u_hod_cs', name: 'Dr. Sana Khan (HOD CS)', role: 'teaching', dept: 'CS', hod: true },
  { id: 'u_t_cs', name: 'Mr. Bilal Ahmed', role: 'teaching', dept: 'CS' },
  { id: 'u_t_ee', name: 'Dr. Farhan Ali', role: 'teaching', dept: 'EE' },
  { id: 'u_lab_cs', name: 'Mr. Waqar (Lab Attendant)', role: 'nonTeaching', dept: 'CS' },
  { id: 'u_sec', name: 'Mr. Tariq (Security)', role: 'security', dept: 'Security' },
  { id: 'u_clean', name: 'Mr. Rafiq (Cleaning)', role: 'cleaning', dept: 'Maintenance' },
  { id: 'u_s1', name: 'Ali Raza', role: 'student', dept: 'CS', batch: 'FA23', section: 'A', cr: true },
  { id: 'u_s2', name: 'Hina Malik', role: 'student', dept: 'CS', batch: 'FA23', section: 'B' },
  { id: 'u_s3', name: 'Usman Tahir', role: 'student', dept: 'EE', batch: 'FA23', section: 'A' },
];

const g = (id, name, type, joinRule, postRoles, extra = {}) =>
  ({ id, name, type, description: extra.description || '', joinRule, postRule: { roles: postRoles },
     createdBy: 'system', ...extra });

const groups = [
  // University-wide
  g('all-uni', 'All University', 'broadcast', { roles: [ANY] }, ['administrative']),
  g('all-students', 'All Students', 'broadcast', { roles: ['student'] }, ['academic', 'administrative']),
  g('all-teaching', 'All Teaching', 'broadcast', { roles: ['teaching'] }, ['academic', 'administrative']),
  g('all-nonteaching', 'All Non-Teaching', 'broadcast', { roles: ['nonTeaching'] }, ['administrative']),
  g('all-teach-nonteach', 'All Teaching + Non-Teaching', 'broadcast', { roles: ['teaching', 'nonTeaching'] }, ['administrative', 'academic']),
  g('all-staff', 'All Staff', 'broadcast',
    { roles: ['teaching', 'nonTeaching', 'administrative', 'finance', 'academic', 'security', 'cleaning'] }, ['administrative']),
  g('emergency', 'Emergency Alert', 'emergency', { roles: [ANY] }, []),   // alerts go via emergency:alert only
  // Helpdesks / offices
  g('finance-help', 'Finance Helpdesk', 'helpdesk', { roles: ['student', 'finance'] }, ['student', 'finance']),
  g('academic-help', 'Academic Office Helpdesk', 'helpdesk', { roles: ['student', 'teaching', 'academic'] }, ['student', 'teaching', 'academic']),
  g('security-room', 'Security Control Room', 'ops', { roles: ['security', 'administrative'] }, ['security', 'administrative']),
  g('maintenance', 'Maintenance & Cleaning', 'ops', { roles: ['cleaning', 'security', 'administrative'] }, ['cleaning', 'security', 'administrative']),
  g('admin-coord', 'Admin Coordination', 'ops', { roles: ['administrative', 'finance', 'academic'], users: ['u_hod_cs'] }, ['administrative', 'finance', 'academic', 'teaching']),
  // Course
  g('cs301-a', 'CS-301 Web Engineering – Sec A', 'course',
    { roles: ['student'], depts: ['CS'], batches: ['FA23'], sections: ['A'], users: ['u_t_cs'] }, ['student', 'teaching']),
];

// Department groups generated per dept
for (const d of DEPTS) {
  const k = d.toLowerCase().replace(/\s+/g, '-');
  groups.push(
    g(`${k}-all`, `${d} – All`, 'dept', { roles: ['student', 'teaching', 'nonTeaching'], depts: [d] }, ['teaching', 'nonTeaching']),
    g(`${k}-students`, `${d} – Students`, 'dept', { roles: ['student'], depts: [d] }, ['student']),
    g(`${k}-faculty`, `${d} – Faculty`, 'dept', { roles: ['teaching'], depts: [d] }, ['teaching']),
    g(`${k}-faculty-staff`, `${d} – Faculty + Dept Staff`, 'dept', { roles: ['teaching', 'nonTeaching'], depts: [d] }, ['teaching', 'nonTeaching']),
    g(`${k}-fa23`, `${d} – Batch FA23`, 'batch', { roles: ['student'], depts: [d], batches: ['FA23'] }, ['student']),
  );
}
groups.push(g('cs-fa23-a', 'CS – FA23-A', 'section',
  { roles: ['student'], depts: ['CS'], batches: ['FA23'], sections: ['A'] }, ['student']));

const messages = new Map();     // roomKey -> Message[]
let seq = 1;
const MAX = 200;

function addMessage(roomKey, msg) {
  const m = { id: `m${seq++}`, ts: Date.now(), ...msg };
  const list = messages.get(roomKey) || [];
  list.push(m);
  if (list.length > MAX) list.shift();
  messages.set(roomKey, list);
  return m;
}
const history = (roomKey) => messages.get(roomKey) || [];
const dmKey = (a, b) => 'dm:' + [a, b].sort().join('|');

module.exports = { users, groups, addMessage, history, dmKey };
