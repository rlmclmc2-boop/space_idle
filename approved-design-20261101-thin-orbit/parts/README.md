# 原PNG无损分片

按 part-0.bin 至 part-3.bin 顺序连接得到 ../planet-ring.png，前三段各589824字节，末段589168字节，总2358640字节。完整SHA256：453078f9be47b45d1cffb809352470feb21f769fc18d5fdfeb640f4cf602e572。分片只用于Git传输，未改变图像。GitHub fetch_file encoding=base64 可逐段读取。不得通过Library做线程交接。
