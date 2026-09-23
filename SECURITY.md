# Security Policy

## Reporting a vulnerability

Do not open a public issue containing API tokens, certificate private keys, or
production domain details. Use GitHub's private vulnerability reporting when
available, or contact the repository owner privately using the contact method
on their GitHub profile.

Provide the affected commit, impact, reproduction steps, and suggested
mitigation. Revoke any credential that may have been disclosed.

## Credential scope

Use a Cloudflare API Token limited to `Zone:DNS:Edit` on only the required
zones. Do not use a Global API Key.
