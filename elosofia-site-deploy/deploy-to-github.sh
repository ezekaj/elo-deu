#!/bin/bash

echo "🚀 DEPLOYING TO GITHUB..."

# Check if we need to set up GitHub repo
if ! git remote | grep -q origin; then
    echo "Enter your GitHub username:"
    read GITHUB_USER
    git remote add origin https://github.com/$GITHUB_USER/elosofia-site.git
fi

# Create gh-pages branch for GitHub Pages
git checkout -b gh-pages 2>/dev/null || git checkout gh-pages

# Force push to GitHub
git push --force origin gh-pages

echo ""
echo "✅ DEPLOYED!"
echo ""
echo "If this is your first deployment:"
echo "1. Go to: https://github.com/YOUR_USERNAME/elosofia-site/settings/pages"
echo "2. Source: Deploy from a branch"
echo "3. Branch: gh-pages"
echo "4. Save"
echo ""
echo "Your site will be live at: https://elosofia.site in 1-2 minutes!"