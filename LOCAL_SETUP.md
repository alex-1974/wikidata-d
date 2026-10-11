# Local repository setup on Alexander's XPS

Target path:

`/home/alexander/Programmiersprachen/dlang/wikidata-d`

The downloadable `wikidata-d.bundle` is a portable Git repository containing the initial `develop` branch and commit history.

```bash
mkdir -p /home/alexander/Programmiersprachen/dlang
git clone "$HOME/Downloads/wikidata-d.bundle" \
    /home/alexander/Programmiersprachen/dlang/wikidata-d
cd /home/alexander/Programmiersprachen/dlang/wikidata-d
git remote remove origin  # disconnect temporary source bundle
git status --short --branch
dub test
```

If your browser downloaded the bundle elsewhere, replace the first path after `git clone`.

The code is an **M1 draft**; compilation with DMD 2.111.0 and LDC 1.41.0 and live Wikidata smoke tests have not yet been performed.

After `git remote remove origin`, no remote is configured. The repository remains local until a GitHub remote is explicitly added.
