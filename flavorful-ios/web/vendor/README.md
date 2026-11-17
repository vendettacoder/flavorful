# Local startup file

`passkeys-web-2.9.0.js` comes from the published `passkeys_web` 2.9.0 package.
The locked Supabase Flutter package includes that package.
Its web registration calls `PasskeyAuthenticator.init()` before the app starts.
The app does not offer passkey sign-in.

The published package includes TypeScript source, but no built JavaScript file.
We built this file without source changes from its `javascript/` directory:

```sh
npm ci --ignore-scripts --no-audit --no-fund
npm run build
```

Use a temporary directory for this build.
Copy `dist/bundle.js` to `passkeys-web-2.9.0.js`.
Keep its line endings unchanged to preserve the checksum.
Do not load the file from a remote server.

Source package: https://pub.dev/packages/passkeys_web/versions/2.9.0

SHA-256 of the published `javascript/package-lock.json`:
`a4dfd12f74d691b07d1c1a67c31567715b856249d932bd9447fc3bfc79493f8c`

SHA-256 of `passkeys-web-2.9.0.js`:
`56a7525e0786cf84490747b0c47d72c3c154dccc7a58b2eb072a36da78a31919`

The file contains local data conversion and browser credential functions.
It contains no network requests.
Startup only creates an object.
Credential functions run only when called.

`LICENSE-passkeys-web.txt` covers the package source.
`LICENSE-webauthn-json.txt` covers its bundled `@github/webauthn-json` dependency.
The JavaScript file retains the Microsoft helper license notice.
