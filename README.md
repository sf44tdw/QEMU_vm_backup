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

