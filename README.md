# kvm_user_vm_backup
KVMのユーザモードVMをバックアップするスクリプト。

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
cd kvm_user_vm_backup && chmod 755 *.sh && cp -fp *.sh /usr/local/bin/
```

