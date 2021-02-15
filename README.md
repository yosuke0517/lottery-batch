# lottery-backend
# システム要件
### サブスクリプション宝くじ当選番号検索アプリ
- 会員登録することで1ヶ月間フリー検索が可能。（自動課金制）

# テーブル設計
- [テーブル設計](https://docs.google.com/spreadsheets/d/1qf94PoMqfEpVkMwJFre9tEFsBqO0vTpGz5La-3Ukxks/edit#gid=0)

# Dockerfile
- [参考](https://www.nullpo.io/2020/04/18/docker-selenium/)

### 決済について
- pay.jpに一任する
- [参考](https://qiita.com/k4ssyi/items/5df5ea12cdffc9597198)

# 未使用のボリュームを削除
$ docker volume prune

### migrationファイル削除
- `find . -path "*/migrations/*.py" -not -name "__init__.py" -delete`

### マイグレーションファイル作成
- `docker-compose run web python manage.py makemigrations`

### マイグレーション実施
- `docker-compose run web python manage.py migrate`

### スーパーユーザ作成
- `docker-compose run web python manage.py createsuperuser`

### データベース接続
- `psql -U lottery -d lotterydb -h localhost`
- テーブル一覧：`\dt`

# デプロイ
### ベースリソースの構築
- `01_base_resources_cfn.yaml`

### EKSクラスターの構築

```
eksctl create cluster \
 --vpc-public-subnets { CloudFormation 出力タブ WorkerSubnetsの値 } \
 --name eks-work-cluster \
 --region ca-central-1 \
 --version 1.14 \
 --nodegroup-name eks-work-nodegroup \
 --node-type t2.small \
 --nodes 2 \
 --nodes-min 2 \
 --nodes-max 5
```

### 上記までの動作確認
- `kubectl apply -f eks-env/02_nginx_k8s.yaml`
- `kubectl port-forward nginx-pod 8080:80`
- `http://localhost:8080`へアクセス
- nginxの画面が表示されることを確認する
- `kubectl delete pod nginx-pod`で片付け

### データベースの構築
##### おおまかな手順

```
- データベースと踏み台サーバを構築する
- SessionManagerを用いて踏み台サーバにアクセスする
- 踏み台サーバ上に必要なツールを導入する
- 踏み台サーバ上でGitリポジトリをクローンする
- データベースに接続し、DDL及びサンプルデータの投入を行う
```

- スタックの作成
  - `10_rds_ope_cfn.yaml`をコンソールから読み込ませて作成する
  - `EksWorkVPC`には`ベースリソースの構築`にて作成したVPCを選択する
  - `OpeServerRouteTable`には`ベースリソースの構築`にて作成したルートテーブルを指定する
    - `eks-work-base`の`出力タブ`→`RouteTable`がキーになっている値部分
  - `スタックオプションの設定`は特に変更なし
  - `レビュー eks-work-rds`にて`AWS CloudFormation によって IAM リソースがカスタム名で作成される場合があることを承認します。`にチェックを入れて`スタックの作成`
  - 踏み台サーバも作成される
  
- セッションマネージャーによる踏み台サーバへの接続
  - セッションマネージャーから`セッションを開始する`を選択
  - git, PostgreSQLクライアントのインストール
    - `sudo yum install -y git`
    - `sudo amazon-linux-extras install -y postgresql10`
    
- エンドポイントの確認
  - 出力タブの`RDSEndpoint`に記載
  
- データベース管理者（rootユーザ）パスワードの確認
  - CloudFormationでデータベースを構築する際、RDSの管理者パスワードをSecrets Managerが作成しデータベースに登録している
  - マネジメントコンソールのSecrets Managerの画面から確認する
  - `RdsMasterSecret`という名前で作成しているのでリンクをクリックして表示
  - `シークレットの値を取得する`ボタンを押下すると秘匿情報が表示される

- アプリケーション用データベースユーザのパスワードの確認
  - `RdsUserSecret`という名前で作成しているのでリンクを上記と同じように確認する
  
- postgresクライアントにてアプリケーション用データベースユーザの作成
  - `createuser -d -U eksdbadmin -P -h { RDSのエンドポイント } mywork`
  - `createuser -d -U {ルートユーザ名} -P -h {RDSエンドポイント} {作成するユーザ名}`
  - 最初の2回は`RdsUserSecret`のパスワード
  - 最後の1回は`RdsMasterSecret`のパスワード
  
- データベースの作成
  - `createdb -U mywork -h { RDSのエンドポイント } -E UTF8 myworkdb`
  - パスワード入力を促されるので`RdsUserSecret`のパスワードを入力する
  
- データベースへの接続とDDLの実行
  - `psql -U mywork -h { RDSのエンドポイント } myworkdb`
  
# 本番環境
- 一旦ec2で

```
//パッケージのアップデート
$ sudo yum update

//Python3インストール
$ sudo yum install python3

//バージョン確認
$ python -V
---------------------------------------------------------------------
Python 2.7.x

//コマンドのディレクトリへ移動
$ cd /usr/bin/

//Python 3のバージョン確認
$ ls pyth*
---------------------------------------------------------------------
python   python2.7         python2-config  python3.7   python-config
python2  python2.7-config  python3         python3.7m

//現在のデフォルトリンク(Python 2系)を解除
$ sudo unlink ./python

//新たにデフォルトリンク(Python 3系)を設定
$ sudo ln -s /usr/bin/python3.7 ./python

//Python 3系がデフォルトになったことを確認
$ python -V
---------------------------------------------------------------------
Python 3.7.x

$ pip3 install selenium --user

// yumの修正
$ sudo vim /usr/bin/yum

#!/usr/bin/python2 ←pythonになっているため2をつける

$ sudo vim /usr/libexec/urlgrabber-ext-down

#!/usr/bin/python2 ←同じく2にする

// Google ChromeとChromeDriverのインストール
$ sudo vi /etc/yum.repos.d/google-chrome.repo
// ↓以下のように編集
[google-chrome]
name=google-chrome
baseurl=http://dl.google.com/linux/chrome/rpm/stable/$basearch
enabled=0
gpgcheck=1
gpgkey=https://dl-ssl.google.com/linux/linux_signing_key.pub

//Chromeのインストール
$ sudo yum install --enablerepo=google-chrome google-chrome-stable

//バージョン確認
$ google-chrome --version
---------------------------------------------------------------------
Google Chrome 86.0.4240.111

// chrome driverをダウンロード（現在の安定版は87
$ wget https://chromedriver.storage.googleapis.com/87.0.4280.88/chromedriver_linux64.zip

//ユーザディレクトリに上がったzipを解凍
sudo unzip /home/ec2-user/chromedriver_linux64.zip

//PATHの通ったディレクトリへ移動
sudo mv /home/ec2-user/chromedriver /usr/local/bin/

// 日本語フォントのインストール
sudo yum install ipa-pgothic-fonts.noarch
```

- pip install で必要なものをインストール：[参考](https://tooaruki.com/system/8682/)

### runserverやmigrate時の設定ファイルの渡し方
  - `python3 manage.py migrate --settings lottery_batch_base.settings.production`
    - 上記のように`--settings`オプションを渡して各環境の場所を指定する
    - 上記ではlottery_backend/settings/production.pyの設定ファイルを読み込んでいる（base.pyは指定しなくて良い）
    
    
# 最新の1件取得をcronで定期実行
- `crontab -e`にてタブを開く
```
AWS_ACCESS_KEY_LOTTERY=XXXXX
AWS_SECRET_ACCESS_KEY_LOTTERY=YYYYY
LINE_TOKEN=ZZZZZ

0 20 * * 1,2 python -m lottery-batch/lottery_batch/latest_scrape_miniloto.py > c
ron-miniloto.log 2>&1
0 20 * * 1,4 python -m lottery-batch/lottery_batch/latest_scrape_lotosix.py > cr
on-lotosix.log 2>&1
0 20 * * 1,5 python -m lottery-batch/lottery_batch/latest_scrape_lotoseven.py > 
cron-lotoseven.log 2>&1
```