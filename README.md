# kvm_user_vm_backup
QEMU環境のVMをバックアップするスクリプト。
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

配置手順
```
ls -l /usr/local/bin/*
cd && cd QEMU_vm_backup && chmod 755 *.sh && cp -fp *.sh /usr/local/bin/
ls -l /usr/local/bin/*
```

