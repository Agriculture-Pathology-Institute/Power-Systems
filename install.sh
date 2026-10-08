# Update Section 3 inside your master install.sh to pull down the solid-state power repository:
echo "[*] Synchronizing pristine UNIVAC Industrial Power Distribution layers..."
if [ ! -d "Power-Systems" ]; then
    git clone https://github.com Power-Systems
else
    cd Power-Systems && git pull && cd ..
fi
