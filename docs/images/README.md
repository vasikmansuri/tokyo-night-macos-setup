# Images

| File | Used for |
| --- | --- |
| `social-preview.png` | The README banner and the GitHub social preview (1280 × 640) |
| `social-preview.svg` | Editable source for `social-preview.png` |
| `terminal-preview.png` | *Not added yet.* A real screenshot of the finished setup. See below. |

The terminal window in the social preview is an illustration, not a screenshot.

## Upload the social preview to GitHub

1. Open the repository on GitHub, then **Settings → General**.
2. Under **Social preview**, click **Edit → Upload an image…**
3. Choose `docs/images/social-preview.png`.

## Re-render the social preview

After editing `social-preview.svg`, render it at exactly 1280 × 640 with Chrome:

```bash
cd docs/images
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --hide-scrollbars \
  --window-size=1280,640 --screenshot="$PWD/social-preview.png" "file://$PWD/social-preview.svg"
```

## Capture `terminal-preview.png`

Use a real screenshot of Ghostty after running the setup.

1. **Use a clean environment** so no personal data shows, for example a demo macOS user account.
2. Open Ghostty and make the window about 1200 × 750 points.
3. `cd` into a small Git repository (this one works) so the prompt shows a branch, then run a few commands that show off the setup, for example:

   ```bash
   clear
   ll
   git status -sb
   cat README.md | head -15
   ```

4. Check that nothing private is visible: your name in paths, tokens, private repositories, or notifications.
5. Press **Cmd + Shift + 4**, then **Space**, and click the Ghostty window. Hold **Option** while clicking to leave out the window shadow.
6. Save it as `docs/images/terminal-preview.png`. If it's over about 1 MB, shrink it: `sips -Z 1600 docs/images/terminal-preview.png`.
7. In the README, replace the "Terminal screenshot" comment near the top with the `<img>` line it contains.
