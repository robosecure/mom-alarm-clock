const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Read firebase CLI config to get refresh token
const configDir = path.join(process.env.HOME, '.config', 'configstore');
const fbConfig = JSON.parse(fs.readFileSync(path.join(configDir, 'firebase-tools.json'), 'utf8'));
const refreshToken = fbConfig.tokens && fbConfig.tokens.refresh_token;

if (refreshToken) {
  admin.initializeApp({
    credential: admin.credential.refreshToken({ clientId: '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com', clientSecret: 'j9iVZfS8kkCEFUPaAeJV0sAi', refreshToken: refreshToken, type: 'authorized_user' }),
    projectId: 'mom-alarm-clock'
  });
} else {
  // Try applicationDefault
  admin.initializeApp({ projectId: 'mom-alarm-clock' });
}

admin.auth().updateUser('oSAHuw5jd8Vo1OzZIrNgCbq1SlF2', { emailVerified: true })
  .then(u => console.log('Email verified:', u.emailVerified))
  .catch(e => console.error('Error:', e.message));
