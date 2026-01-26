#!/bin/ksh
# install_fontawesome6.ksh
# Automatically installs FontAwesome6 for TeX (XeLaTeX/LuaLaTeX)

set -e

# --- 1. Temporary working directory ---
TMPDIR=$(mktemp -d)
echo "Working in temporary directory: $TMPDIR"
cd "$TMPDIR"

# --- 2. Download and unzip CTAN package ---
echo "Downloading FontAwesome6 from CTAN..."
ftp -o fontawesome.zip https://mirrors.ctan.org/fonts/fontawesome.zip
unzip fontawesome.zip

# Find unpacked directory
FA_DIR=$(find . -maxdepth 1 -type d -name "fontawesome*" | head -n1)
cd "$FA_DIR"

# --- 3. Create local texmf directories ---
mkdir -p ~/texmf/tex/latex/fontawesome6
mkdir -p ~/texmf/fonts/map/dvips/fontawesome6
mkdir -p ~/texmf/fonts/tfm/fontawesome6
mkdir -p ~/texmf/fonts/opentype/fontawesome6
mkdir -p ~/texmf/fonts/type1/fontawesome6

# --- 4. Copy files ---
cp -r tex/* ~/texmf/tex/latex/fontawesome6/
cp map/*.map ~/texmf/fonts/map/dvips/fontawesome6/
cp -r tfm/* ~/texmf/fonts/tfm/fontawesome6/
cp -r opentype/* ~/texmf/fonts/opentype/fontawesome6/
cp -r type1/* ~/texmf/fonts/type1/fontawesome6/

# --- 5. Update TeX filename database ---
echo "Updating TeX filename database..."
mktexlsr

# --- 6. Install OTF fonts for XeLaTeX/LuaLaTeX ---
mkdir -p ~/.local/share/fonts/fontawesome6
cp -r opentype/* ~/.local/share/fonts/fontawesome6/
fc-cache -fv

# --- 7. Cleanup ---
cd
rm -rf "$TMPDIR"

echo "FontAwesome6 installation complete!"
echo "LaTeX package installed in ~/texmf/tex/latex/fontawesome6"
echo "OTF fonts installed in ~/.local/share/fonts/fontawesome6"

