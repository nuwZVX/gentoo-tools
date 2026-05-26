emerge emerge app-arch/dpkg sys-apps/i2c-tools dev-python/smbus2 dev-python/urwid

wget https://github.com/PiSupply/PiJuice/raw/refs/heads/master/Software/Install/pijuice-base_1.8_all.deb

dpkg --ignore-depends=python3,i2c-tools,python3-smbus,python3-urwid -i pijuice-base*

useradd --shell /bin/false --home /var/lib/pijuice pijuice

chown -R pijuice:pijuice /var/lib/pijuice
chown pijuice:pijuice /usr/bin/pijuice_*

echo "dtparam=i2c_arm=on" >> /boot/config.txt
