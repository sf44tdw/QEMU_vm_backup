# kvm_user_vm_backup
QEMU環境のVMをバックアップするスクリプト。

スクリプトを実行したときのカレントディレクトリ下に以下のファイルをバックアップする。

root以外のユーザで実行した場合は、実行したユーザの~/.config/libvirt/下のユーザモードVMと、~/.local/share/libvirt/images下のqcow2ディスクイメージをバックアップする。

rootユーザで実行した場合は、/etc/libvirt/qemu下のVMと、それらのVMの/var/lib/libvirt/images下のqcow2ディスクイメージをバックアップする。

注意 アーカイブの圧縮にpigzを使用するのでインストールしておく必要がある。

fedora40の場合。
```
dnf -y install pigz
```

参考 pigzによるtgz解凍コマンド
```
tar -I pigz -xf xxx.tgz
```

RPMパッケージ
```
VERSION=1.0.0
sudo dnf install ./backup-vmqcow-"${VERSION}"-1*.noarch.rpm
```

`VERSION`は利用するリリースのバージョンに置き換えてください。RPMをインストールすると、`backup_vmqcow.sh`は`/usr/bin/backup_vmqcow.sh`に配置されます。依存コマンドもRPM経由でインストールされます。GitHub Releasesで公開されたリリースには、ビルド済みRPMが添付されます。

手動で配置する場合
```
ls -l /usr/local/bin/*
cd && cd QEMU_vm_backup && chmod 755 *.sh && cp -fp *.sh /usr/local/bin/
ls -l /usr/local/bin/*
```
