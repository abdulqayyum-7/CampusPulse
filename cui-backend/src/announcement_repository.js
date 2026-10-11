const fs = require('fs/promises');
const path = require('path');

const file = path.join(__dirname, '..', 'data', 'announcements.json');
let records = [];
let writeQueue = Promise.resolve();

async function load() {
  try {
    const parsed = JSON.parse(await fs.readFile(file, 'utf8'));
    records = Array.isArray(parsed) ? parsed : [];
  } catch (error) {
    if (error.code !== 'ENOENT') throw error;
    records = [];
  }
}

function persist() {
  writeQueue = writeQueue.catch(() => {}).then(async () => {
    const snapshot = JSON.stringify(records, null, 2);
    await fs.mkdir(path.dirname(file), { recursive: true });
    const temp = `${file}.tmp`;
    await fs.writeFile(temp, snapshot, 'utf8');
    await fs.rename(temp, file);
  });
  return writeQueue;
}

function list() {
  return [...records].sort((a, b) => b.createdAt - a.createdAt);
}

async function create(record) {
  records.unshift(record);
  try {
    await persist();
    return record;
  } catch (error) {
    records = records.filter(item => item.id !== record.id);
    throw error;
  }
}

async function remove(id) {
  const existing = records.find(item => item.id === id);
  if (!existing) return null;
  records = records.filter(item => item.id !== id);
  try {
    await persist();
    return existing;
  } catch (error) {
    records.push(existing);
    throw error;
  }
}

module.exports = { load, list, create, remove };
