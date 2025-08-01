# Deploy to GitHub Pages

Your deployment is ready! Follow these steps to push to GitHub:

## 1. Create GitHub Repository

If you haven't already, create a repository on GitHub for elosofia.site.

## 2. Add GitHub Remote

```bash
cd /home/elo/elo-deu/github-deploy
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git
```

## 3. Push to GitHub

```bash
git push -u origin master
```

## 4. Enable GitHub Pages

1. Go to your repository on GitHub
2. Click on "Settings"
3. Scroll down to "Pages"
4. Under "Source", select "Deploy from a branch"
5. Choose "master" branch and "/ (root)" folder
6. Click "Save"

## 5. Keep Backend Running

The backend services need to stay running. Use the keep-running script:

```bash
cd /home/elo/elo-deu
./keep-running.sh
```

## Current Tunnel URLs

Your current backend services are running at:
- Calendar API: https://bulgaria-editorials-several-rack.trycloudflare.com
- Voice Service: https://laboratories-israel-focusing-airport.trycloudflare.com

## Important Notes

- Keep the terminal with tunnels running open
- The tunnels will stop if you close the terminal
- GitHub Pages will handle the frontend (elosofia.site)
- Your machine handles the backend (via tunnels)

## Testing

Once deployed, visit:
- Main site: https://elosofia.site
- Direct GitHub URL: https://YOUR_USERNAME.github.io/YOUR_REPO_NAME