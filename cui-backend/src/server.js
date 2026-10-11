const express = require('express');
const http = require('http');
const cors = require('cors');
const jwt = require('jsonwebtoken');
const { Server } = require('socket.io');
const store = require('./store');
const rules = require('./rules');
const announcementRepository = require('./announcement_repository');

if (process.env.NODE_ENV === 'production' && !process.env.JWT_SECRET) {
  throw new Error('JWT_SECRET must be configured in production');
}
const SECRET = process.env.JWT_SECRET || 'dev-secret-change-me';
const PORT = process.env.PORT || 3000;
const app = express();
app.use(cors());
app.use(express.json({ limit: '1mb' }));
const server = http.createServer(app);
const io = new Server(server, { cors: { origin: '*' } });

const byId = (id) => store.users.find(u => u.id === id);
const groupById = (id) => store.groups.find(g => g.id === id);
const announcementRoles = ['student', 'teaching', 'nonTeaching', 'finance', 'academic', 'administrative', 'security', 'cleaning', 'admin'];
const demoPassword = (role) => ({ admin: 'Admin123', student: 'Student123', teaching: 'Teacher123', nonTeaching: 'Staff123', finance: 'Finance123', academic: 'Academic123', administrative: 'Office123', security: 'Security123', cleaning: 'Cleaning123' }[role] || 'Demo123');
const pub = (u) => ({ id: u.id, username: u.username || u.id, name: u.name, role: u.role, dept: u.dept, batch: u.batch, section: u.section, hod: !!u.hod });
const gRoom = (id) => `g:${id}`;
const groupView = (u, g) => ({ ...g, canPost: rules.canPost(u, g), canManage: rules.canManageGroup(u, g) });
const myGroups = (u) => store.groups.filter(g => rules.isMember(u, g)).map(g => groupView(u, g));

// ---------- room sync: keeps socket rooms == rule-derived membership ----------
function syncSocket(sock) {
  const u = byId(sock.data.userId);
  if (!u) return sock.disconnect(true);
  sock.join([`u:${u.id}`, `r:${u.role}`]);
  for (const g of store.groups) {
    const should = rules.isMember(u, g);
    const has = sock.rooms.has(gRoom(g.id));
    if (should && !has) { sock.join(gRoom(g.id)); sock.emit('group:joined', groupView(u, g)); }
    if (!should && has) { sock.leave(gRoom(g.id)); sock.emit('group:left', { groupId: g.id }); }
  }
}
const syncAll = () => io.sockets.sockets.forEach(syncSocket);

// ---------- REST (demo login + admin user mgmt) ----------
app.post('/api/login', (req, res) => {
  const username = String(req.body?.username || '').trim();
  const password = String(req.body?.password || '');
  const u = store.users.find(x => (x.username || x.id) === username && demoPassword(x.role) === password);
  if (!u) return res.status(401).json({ error: 'Invalid username or password' });
  res.json({ token: jwt.sign({ id: u.id }, SECRET, { expiresIn: '12h' }), user: pub(u) });
});
const auth = (req, res, next) => {
  try {
    const { id } = jwt.verify((req.headers.authorization || '').replace('Bearer ', ''), SECRET);
    req.user = byId(id); return req.user ? next() : res.sendStatus(401);
  } catch { res.sendStatus(401); }
};
const adminOnly = (req, res, next) => req.user.role === 'admin' ? next() : res.status(403).json({ error: 'admin only' });

app.get('/api/users', auth, (_, res) => res.json(store.users.map(pub)));
app.get('/api/me/groups', auth, (req, res) => res.json(myGroups(req.user)));
app.get('/api/groups', auth, adminOnly, (_, res) => res.json(store.groups));
app.post('/api/users', auth, adminOnly, (req, res) => {
  const { name, role, dept, batch, section, hod } = req.body || {};
  if (!name || !role) return res.status(400).json({ error: 'name and role required' });
  const id = 'u_' + Date.now().toString(36);
  const u = { id, username: id, name, role, dept, batch, section, hod: !!hod };
  store.users.push(u); syncAll(); res.status(201).json(pub(u));
});
app.delete('/api/users/:id', auth, adminOnly, (req, res) => {
  const i = store.users.findIndex(u => u.id === req.params.id);
  if (i < 0) return res.sendStatus(404);
  store.users.splice(i, 1); syncAll(); res.sendStatus(204);
});

// ---------- durable campus announcements ----------
const canSeeAnnouncement = (user, item) => user.role === 'admin' || item.audienceRoles.includes(user.role);
const announcementRooms = roles => [...new Set([...roles, 'admin'])].map(role => `r:${role}`);

app.get('/api/announcements', auth, (req, res) => {
  res.json(announcementRepository.list().filter(item => canSeeAnnouncement(req.user, item)));
});

app.post('/api/announcements', auth, async (req, res) => {
  const category = String(req.body?.category || '').trim();
  const title = String(req.body?.title || '').trim();
  const body = String(req.body?.body || '').trim();
  if (!['event', 'scholarship'].includes(category)) return res.status(400).json({ error: 'Choose an event or scholarship announcement' });
  if (!rules.canPublishAnnouncement(req.user, category)) return res.status(403).json({ error: `Your ${req.user.role} role cannot publish ${category} announcements` });
  if (title.length < 4 || title.length > 120) return res.status(400).json({ error: 'Title must be 4 to 120 characters' });
  if (body.length < 10 || body.length > 5000) return res.status(400).json({ error: 'Details must be 10 to 5000 characters' });
  const rawRoles = req.body?.audienceRoles;
  const audienceRoles = rawRoles == null ? [...announcementRoles] : rawRoles;
  if (!Array.isArray(audienceRoles) || audienceRoles.length === 0 || audienceRoles.some(role => !announcementRoles.includes(role))) {
    return res.status(400).json({ error: 'Choose at least one valid audience role' });
  }
  const parsedDeadline = req.body?.deadline ? new Date(req.body.deadline) : null;
  if (parsedDeadline && !Number.isFinite(parsedDeadline.getTime())) return res.status(400).json({ error: 'Invalid deadline' });
  const deadline = parsedDeadline?.toISOString() || null;
  const item = {
    id: require('crypto').randomUUID(), category, title, body, deadline,
    audienceRoles: [...new Set(audienceRoles)], createdAt: Date.now(),
    authorityId: req.user.id, authorityName: req.user.name, authorityRole: req.user.role,
  };
  try {
    await announcementRepository.create(item);
    io.to(announcementRooms(item.audienceRoles)).emit('announcement:new', item);
    res.status(201).json(item);
  } catch (error) {
    console.error('Could not save announcement:', error);
    res.status(500).json({ error: 'Could not save announcement' });
  }
});

app.delete('/api/announcements/:id', auth, async (req, res) => {
  const item = announcementRepository.list().find(x => x.id === req.params.id);
  if (!item) return res.sendStatus(404);
  if (req.user.role !== 'admin' && item.authorityId !== req.user.id) return res.status(403).json({ error: 'Only the publishing authority can remove this announcement' });
  try {
    await announcementRepository.remove(item.id);
    io.to(announcementRooms(item.audienceRoles)).emit('announcement:removed', { id: item.id });
    res.sendStatus(204);
  } catch (error) {
    console.error('Could not remove announcement:', error);
    res.status(500).json({ error: 'Could not remove announcement' });
  }
});

// ---------- Socket auth ----------
io.use((socket, next) => {
  try {
    const { id } = jwt.verify(socket.handshake.auth?.token, SECRET);
    if (!byId(id)) throw new Error('no user');
    socket.data.userId = id; next();
  } catch { next(new Error('unauthorized')); }
});

const online = new Map();   // userId -> connection count

io.on('connection', (socket) => {
  const me = () => byId(socket.data.userId);
  const deny = (cb, message) => { socket.emit('error:forbidden', { message }); cb?.({ ok: false, error: message }); };

  syncSocket(socket);
  online.set(me().id, (online.get(me().id) || 0) + 1);
  io.emit('presence:update', { userId: me().id, online: true });
  socket.emit('ready', { user: pub(me()), groups: myGroups(me()), onlineUserIds: [...online.keys()] });

  socket.on('group:history', ({ groupId }, cb) => {
    const g = groupById(groupId);
    if (!g || !rules.isMember(me(), g)) return deny(cb, 'Not a member of this group');
    cb?.({ ok: true, messages: store.history(gRoom(groupId)) });
  });

  socket.on('group:message', ({ groupId, text }, cb) => {
    const g = groupById(groupId);
    text = String(text || '').trim().slice(0, 2000);
    if (!g || !text) return deny(cb, 'Invalid message');
    if (!rules.canPost(me(), g)) return deny(cb, `You are not allowed to post in ${g.name}`);
    const u = me();
    const msg = store.addMessage(gRoom(groupId), { groupId, senderId: u.id, senderName: u.name, senderRole: u.role, text });
    io.to(gRoom(groupId)).emit('group:message', msg);
    cb?.({ ok: true, message: msg });
  });

  socket.on('typing', ({ groupId, toUserId }) => {
    const u = me();
    if (groupId) {
      const g = groupById(groupId);
      if (g && rules.canPost(u, g)) socket.to(gRoom(groupId)).emit('typing', { groupId, userId: u.id, name: u.name });
    } else if (toUserId) socket.to(`u:${toUserId}`).emit('typing', { dmWith: u.id, name: u.name });
  });

  socket.on('dm:send', ({ toUserId, text }, cb) => {
    const to = byId(toUserId), u = me();
    text = String(text || '').trim().slice(0, 2000);
    if (!to || !text) return deny(cb, 'Invalid DM');
    if (!rules.canDm(u, to, store.groups)) return deny(cb, "You can't message this user. No shared group or role permission.");
    const msg = store.addMessage(store.dmKey(u.id, to.id), { fromId: u.id, toId: to.id, senderName: u.name, senderRole: u.role, text });
    io.to([`u:${u.id}`, `u:${to.id}`]).emit('dm:message', msg);
    cb?.({ ok: true, message: msg });
  });

  socket.on('dm:history', ({ withUserId }, cb) => {
    const to = byId(withUserId);
    if (!to || !rules.canDm(me(), to, store.groups)) return deny(cb, 'Not allowed');
    cb?.({ ok: true, messages: store.history(store.dmKey(me().id, withUserId)) });
  });

  socket.on('dm:candidates', (_, cb) => {      // for the "new chat" screen: who can I DM, and who is blocked
    const u = me();
    cb?.(store.users.filter(x => x.id !== u.id).map(x => {
      const allowed = rules.canDm(u, x, store.groups);
      return { ...pub(x), allowed, reason: allowed ? null : 'No shared group or role permission' };
    }));
  });

  socket.on('emergency:alert', ({ type, location, note }, cb) => {
    const u = me();
    const alert = { id: 'a' + Date.now(), type: type || 'Other', location: location || 'Unknown', note: note || '',
      from: pub(u), ts: Date.now(), priority: 'high' };
    store.addMessage('emergency', { ...alert, text: `${alert.type} @ ${alert.location}` });
    io.to(['r:security', 'r:admin']).emit('emergency:alert', alert);       // security + admin first
    cb?.({ ok: true, alert });
  });
  socket.on('emergency:ack', ({ alertId }) => {
    io.to(['r:security', 'r:admin']).emit('emergency:ack', { alertId, by: me().name, ts: Date.now() });
  });

  socket.on('group:create', ({ name, description, joinRule, postRule }, cb) => {
    const u = me();
    if (!name || !joinRule) return deny(cb, 'name and joinRule required');
    if (!rules.canCreateGroup(u, joinRule)) return deny(cb, 'Only Admin or HOD (own department) can create groups');
    const grp = { id: 'g_' + Date.now().toString(36), name, description: description || '', type: 'custom',
      joinRule, postRule: postRule || { roles: [rules.ANY] }, createdBy: u.id };
    store.groups.push(grp); syncAll();
    cb?.({ ok: true, group: groupView(u, grp) });
  });

  const manage = (fn) => ({ groupId, userId }, cb) => {
    const g = groupById(groupId), t = byId(userId);
    if (!g || !t) return deny(cb, 'Not found');
    if (!rules.canManageGroup(me(), g)) return deny(cb, 'You cannot manage this group');
    g.joinRule = g.joinRule || {}; fn(g.joinRule, userId); syncAll(); cb?.({ ok: true });
  };
  const add = (set, k, v) => { set[k] = [...new Set([...(set[k] || []), v])]; };
  const del = (set, k, v) => { set[k] = (set[k] || []).filter(x => x !== v); };
  socket.on('group:addMember', manage((j, id) => { add(j, 'users', id); del(j, 'excludeUsers', id); }));
  socket.on('group:removeMember', manage((j, id) => { del(j, 'users', id); add(j, 'excludeUsers', id); }));

  socket.on('group:members', ({ groupId }, cb) => {
    const g = groupById(groupId);
    if (!g || !rules.isMember(me(), g)) return deny(cb, 'Not a member');
    cb?.({ ok: true, members: store.users.filter(u => rules.isMember(u, g)).map(u => ({ ...pub(u), online: online.has(u.id) })) });
  });

  socket.on('disconnect', () => {
    const id = socket.data.userId, n = (online.get(id) || 1) - 1;
    if (n <= 0) { online.delete(id); io.emit('presence:update', { userId: id, online: false }); } else online.set(id, n);
  });
});

announcementRepository.load().then(() => {
  server.listen(PORT, '0.0.0.0', () => console.log(`CampusPulse API + Socket.IO on :${PORT}`));
}).catch(error => {
  console.error('Could not load announcement store:', error);
  process.exitCode = 1;
});

