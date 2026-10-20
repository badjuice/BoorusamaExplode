# BoorusamaExplode

[![License](https://img.shields.io/badge/license-GPLv3-blue)](https://www.gnu.org/licenses/gpl-3.0)

A fork of [Boorusama](https://github.com/khoadng/Boorusama) by khoadng, forked from upstream 4.6.1. Changes so far are tested against realbooru.com. A later version will drop the other sites and focus on realbooru only.

The Android app ID is `org.rdcl.badjuice.boorusamaexplode`, so it installs next to the official Boorusama instead of replacing it.

## Changes from upstream

### Realbooru
- Comments load from the post page. Realbooru's API returns "API offline" for every request, so the upstream comment fetch always came back empty.
- Tags on the post page show post counts, read from the sidebar of an `id:<post>` search.
- List pages give tags as `tag one, tag two`. Upstream split them on spaces, which turned `big ass` into `big` and `ass,`.
- Thumbnails mark videos and GIFs. The list page has no file extension, so videos are detected by the blue thumbnail border or a `video`/`webm` tag, and GIFs by the `animated_gif` tag.
- You can swipe between posts. Each post page is fetched as you reach it; until then the thumbnail shows with a spinner, or a retry button if the fetch fails.

### Downloads
- Downloading several selected posts works. The list page only gives a thumbnail, and upstream guessed the file URL as `.jpg`, so `.mp4`, `.webm` and `.jpeg` files returned 404. The real URL now comes from each post page.
- A post that is already downloaded or queued is skipped. Long-press the download button and pick a quality to save it again.
- Downloaded posts get a badge on the thumbnail, and the download button turns into a check mark.
- Download history survives an app restart.
- Download manager tabs switch by swiping and show a count each.
- Files go in a folder per site by default (`Download/realbooru.com/`). Settings has switches for a folder per search and for separate `images`, `gifs` and `videos` folders.
- The Downloads page has a gallery of downloaded files, with an option to download a missing file again.

### Viewing
- Losing the connection no longer wipes open pages. Upstream swapped the widget above the app's navigator when the network dropped, so every page rebuilt and the post viewer showed "Invalid context: null". A small "Network unavailable" pill now appears at the bottom instead.
- Long-press a back button to jump several pages back, or forward to a page you just left.
- Thumbnails show a loading spinner and the post viewer a thin progress bar, with a retry button when an image fails.
- During a call, or when another app plays sound, videos keep playing muted. Settings > Image viewer has two other choices: pause and resume, or keep the sound on. This applies to the default player; upstream plays `.webm` on Android through a WebView, which handles audio its own way.

## Building

You need Flutter 3.47.2 (pinned in `.fvmrc`), the Android SDK and Rust. The AVIF decoder compiles native code, so you also need Meson and Ninja. On Windows you need the Visual Studio "Desktop development with C++" workload as well.

```bash
git clone https://github.com/badjuice/BoorusamaExplode.git
cd BoorusamaExplode
./init.sh
flutter build apk --flavor prod --release --split-per-abi --target-platform android-arm64,android-arm
```

On Windows, enable git long paths before `./init.sh`, or some git dependencies fail to clone:

```bash
git config --global core.longpaths true
```

Release builds are signed with the key in `android/key.properties`. Without that file they fall back to the debug key.

## License

GPLv3, same as upstream.
