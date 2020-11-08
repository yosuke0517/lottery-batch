import os


def write_df_to_s3(df, outpath):
    """
    s3にファイルを書き出す処理
    """
    import s3fs
    key = os.environ['AWS_ACCESS_KEY_LOTTERY']
    secret = os.environ['AWS_SECRET_ACCESS_KEY_LOTTERY']
    bytes_to_write = df.to_csv(None, index=False).encode()
    fs = s3fs.S3FileSystem(key=key, secret=secret)
    with fs.open(outpath, 'wb') as f:
        f.write(bytes_to_write)