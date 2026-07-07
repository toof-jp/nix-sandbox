# sakura-vps 手動作業ドキュメント

さくらのVPS上の NixOS ノード（zen2 クラスタの control-plane）の構築手順。
Nix で宣言化されている部分（固定IP、kubelet の `--node-ip`、systemd-resolved など）は
`make deploy` 系で再現されるが、以下は**手動作業が必要**。

## 構成

| 項目 | 値 |
|---|---|
| 公開IP | 153.126.161.157 (/23, GW 153.126.160.1, DHCPなし・固定設定) |
| tailscale IP | 100.117.158.100 |
| 役割 | kubeadm control-plane（zen2 クラスタに参加） |
| SSH | `ssh root@153.126.161.157`（鍵認証のみ） |

## 1. インストーラISOの作成とアップロード

```sh
make sakura-iso   # result/iso/nixos-minimal-*.iso ができる
```

さくらのコントロールパネル → 対象VPS → OS再インストール → ISOイメージインストール で
SFTPアカウントを発行し、アップロードする:

```sh
sftp <user>@vps-isoX.sakura.ad.jp
cd iso
put result/iso/nixos-minimal-*.iso
```

- ISOには固定IP設定（`network.nix`）とSSH公開鍵が焼き込み済み。起動すればネットワークは自動で上がる
- パケットフィルタで TCP 22 が許可されているか確認すること

## 2. OSインストール

コントロールパネルでISOをマウントして起動し、コンソールまたは SSH で:

```sh
sakura-install   # ISOに焼き込み済みのスクリプト。YES と入力すると実行
```

やること（スクリプトの中身）: `/dev/vda` を GPT + BIOS boot パーティションで初期化 →
ext4 (label: nixos) → 一時swap 2GB 作成（closureコピーのOOM対策。本番設定にswapは無い。
**kubeletはswap有効だと起動しない**ため） → `nixos-install --flake github:toof-jp/nix-sandbox#sakura-vps`

完了したらコントロールパネルで**ISOのマウントを解除してから** `reboot`。

インストーラのユーザーは `nixos`（パスワード空、sudo可）。rootパスワードも空。

## 3. Tailscale 参加

```sh
ssh root@153.126.161.157
tailscale up    # 表示されるURLをブラウザで開いて認証
tailscale ip -4 # → 100.117.158.100 のはず
```

IPが変わった場合は `sakura-vps/configuration.nix` の `kubernetesNode.nodeIP` を更新して再デプロイ。

## 4. zen2 クラスタへの control-plane join

### 4.1 zen2 側の前提（対応済み・一度きり）

zen2 のクラスタは元々 LAN IP (192.168.3.2) しか使っていなかったため、
tailscale 経由で join できるように以下を変更済み。**再インストール時に再実行は不要**だが、
zen2 を作り直した場合はやり直しになる:

- `etcd.yaml` の `--listen-client-urls` / `--listen-peer-urls` に `100.83.127.53` を追加
- `--advertise-client-urls` と annotation `kubeadm.kubernetes.io/etcd.advertise-client-urls` を
  `https://100.83.127.53:2379` **のみ**に変更（kubeadm はリスト先頭しか使わないため、
  到達不能な LAN IP が先頭にあると join が固まる）
- `etcdctl member update <zen2-id> --peer-urls=https://100.83.127.53:2380`（同上の理由でtailscaleのみ）
- etcd server/peer 証明書を SAN `100.83.127.53` 入りで再生成
  （`kubeadm init phase certs etcd-server|etcd-peer --config <serverCertSANs入りconfig>`）
- apiserver 証明書を SAN `100.83.127.53` 入りで再生成
- ClusterConfiguration に `controlPlaneEndpoint: 100.83.127.53:6443` を設定して
  `kubeadm init phase upload-config kubeadm` でアップロード（未設定だと control-plane join 不可）
- kube-public の `cluster-info` ConfigMap の server を `https://100.83.127.53:6443` に変更
  （join はここに書かれたアドレスに接続する）

**注意: `/etc/kubernetes/manifests/` の中にバックアップファイルを置かないこと。**
kubelet がディレクトリ内の全ファイルをマニフェストとして読むため、同名Podが競合して
設定変更が反映されなくなる（今回この罠で1時間溶かした）。

### 4.2 join 手順

zen2 で join トークンと証明書キーを発行:

```sh
sudo kubeadm token create --print-join-command
sudo kubeadm init phase upload-certs --upload-certs   # certificate key は2時間有効
```

sakura-vps で（事前に `kubeadm reset -f` してから）:

```sh
kubeadm join 100.83.127.53:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash> \
  --control-plane \
  --certificate-key <certificate-key> \
  --apiserver-advertise-address=100.117.158.100 \
  --node-name sakura-vps
```

- `--apiserver-advertise-address` に tailscale IP を指定するのが重要
  （これが etcd の advertise / 証明書 SAN にも使われる）
- `--node-name` を明示するのは、ホスト名衝突事故の予防

### 4.3 join に失敗した場合の掃除

join が途中で失敗すると etcd に未起動の learner メンバーが残り、次の join を妨げる。
zen2 で確認・削除:

```sh
sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf exec -n kube-system etcd-zen2 -- \
  etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt \
          --cert=/etc/kubernetes/pki/etcd/peer.crt \
          --key=/etc/kubernetes/pki/etcd/peer.key \
          --endpoints=https://127.0.0.1:2379 member list
# name が空で isLearner の ID を削除
sudo kubectl ... member remove <hex-id>
```

sakura-vps 側は `kubeadm reset -f` してから再 join。

## 5. 運用上の注意

- **etcd は現在2メンバー（zen2 + sakura-vps）。クォーラムは2なので、どちらか片方が
  落ちるとクラスタ全体が書き込み不能になる。** 3台目の追加を推奨
- 両ノードとも control-plane taint (`node-role.kubernetes.io/control-plane:NoSchedule`)
  が付いているため、アプリPodは worker を join させるか taint を外さないと動かない
- ノード間通信（apiserver / etcd / kubelet）はすべて tailscale (100.x) 経由。
  tailscale が落ちるとクラスタ通信も止まる
- swap は意図的に無効（kubelet の制約）。メモリ2GBと少ないので重いworkloadは載せないこと

## トラブルシューティング履歴（原因と対策の索引）

| 症状 | 原因 | 対策 |
|---|---|---|
| インストーラがネットに出られない | さくらのVPSはDHCPなし | `network.nix` で固定IP（ISOに焼き込み済み） |
| `kubeadm init/join` がswapエラー | kubeletはswap非対応 | 本番設定からswap削除済み |
| Pod sandbox作成失敗 `/run/systemd/resolve/resolv.conf` | クラスタのkubelet設定がsystemd-resolved前提 | `services.resolved.enable = true`（設定済み） |
| join がetcd接続でタイムアウト | メンバーURL先頭が到達不能なLAN IP | member update / advertise URLをtailscaleのみに |
| etcd設定変更が反映されない | manifests/内のバックアップファイルが競合 | manifests/にはマニフェスト以外置かない |
| ノードのINTERNAL-IPが公開IPになる | kubeletのIP自動検出 | `kubernetesNode.nodeIP`で`--node-ip`指定（設定済み） |
