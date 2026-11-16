# ollama-qwen3-embedding-0.6B

开箱即用的离线 Docker 镜像方案：基于最新版 `ollama/ollama:latest` 预置 `qwen3-embedding:0.6b` 向量模型（1024 维），并集成最新版 `Qdrant` 向量数据库，支持完全断网环境一键加载并同时启动 **Embedding API 服务 + Qdrant 向量数据库服务**。

---

## 架构设计与技术选型

1. **Embedding 引擎 + 向量库单容器一体集成**
   - **Ollama (`0.40.16+`) + `qwen3-embedding:0.6b`**：在 `Dockerfile` 构建阶段拉取并固化模型权重至 `/root/.ollama/models`（约 639 MB），支持 Ollama 原生 `/api/embed` 与 OpenAI 兼容 `/v1/embeddings` 接口。
   - **Qdrant (`qdrant/qdrant:latest`)**：通过多阶段构建集成 Qdrant 二进制、默认配置与 Web Dashboard UI，由 [entrypoint.sh](entrypoint.sh) 统一托管进程生命周期与信号转发（任一服务异常退出即联动退出，配合 `restart: unless-stopped` 自愈）。
2. **开箱即用的服务参数调优**
   - `OLLAMA_HOST=0.0.0.0:11434`：默认监听所有网卡，宿主机及局域网可直接访问。
   - `OLLAMA_KEEP_ALIVE=-1`：常驻内存不自动卸载，避免向量检索场景下的冷启动延迟。
   - Qdrant 默认监听 `6333`（HTTP API & Web UI）与 `6334`（gRPC），数据目录 `/qdrant/storage` 支持持久化卷挂载。
   - 内置 `HEALTHCHECK`：同时检查 Ollama 模型列表与 Qdrant `/readyz` 就绪状态。
3. **适配 GitHub Release 2 GB 限制的分片离线包**
   - 离线镜像导出压缩后体积约 3.8~4.0 GB，超过 GitHub Release 单文件 **2 GB** 上限。
   - 打包脚本使用 `pigz`/`gzip` 压缩后按 `1800M` 自动切分为 `*.tar.gz.part.00`、`*.tar.gz.part.01` ... 并生成 `SHA256SUMS` 校验文件。
   - Linux/macOS/WSL 可通过管道流式 `cat ... | docker load` 直接导入，无需额外合并占用双倍磁盘空间。

---

## 暴露端口与目录说明

| 端口 / 目录 | 服务 | 说明 |
| --- | --- | --- |
| `11434` | Ollama | Embedding API（`/api/embed`、`/v1/embeddings`） |
| `6333` | Qdrant | HTTP REST API 与 Web 管理界面（`http://localhost:6333/dashboard`） |
| `6334` | Qdrant | gRPC 高性能接口 |
| `/qdrant/storage` | Qdrant | 向量索引与数据持久化目录（建议挂载 Volume） |

---

## 一、离线部署使用指南（终端用户）

### 1. 下载离线包

前往本仓库的 [GitHub Releases](https://github.com/JayYang1991/ollama-qwen3-embedding-0.6B/releases) 页面，下载对应版本下的全部文件到同一目录：

- `ollama-qwen3-embedding-0.6b-<tag>.tar.gz.part.00`
- `ollama-qwen3-embedding-0.6b-<tag>.tar.gz.part.01`
- `ollama-qwen3-embedding-0.6b-<tag>.tar.gz.part.02`（视实际分片数量而定）
- `SHA256SUMS`

### 2. 校验并导入 Docker 镜像

#### Linux / macOS / WSL

方式 A：使用项目自带脚本（推荐，自动校验 SHA256）：

```bash
chmod +x scripts/load.sh
./scripts/load.sh /path/to/downloaded-dir
```

方式 B：手动校验并流式导入（无需额外磁盘空间）：

```bash
cd /path/to/downloaded-dir
sha256sum -c SHA256SUMS
cat ollama-qwen3-embedding-0.6b-*.tar.gz.part.* | docker load
```

#### Windows PowerShell

使用项目自带 PowerShell 脚本（自动校验 SHA256、合并、导入并清理临时文件）：

```powershell
.\scripts\load.ps1 -DistDir "C:\path\to\downloaded-dir"
```

导入成功后，可通过以下命令确认镜像（若导入的标签为具体版本号如 `v1.0.0`，可按需 `docker tag` 为 `latest`）：

```bash
docker images ollama-qwen3-embedding-0.6b
```

---

### 3. 启动模型与向量库服务

#### 方式 A：直接使用 `docker run`

**CPU 模式：**

```bash
docker run -d \
  --name ollama-qwen3-embedding \
  -p 11434:11434 \
  -p 6333:6333 \
  -p 6334:6334 \
  -v qdrant_storage:/qdrant/storage \
  --restart unless-stopped \
  ollama-qwen3-embedding-0.6b:latest
```

**NVIDIA GPU 加速模式（需宿主机已安装 `nvidia-container-toolkit`）：**

```bash
docker run -d \
  --name ollama-qwen3-embedding \
  --gpus all \
  -p 11434:11434 \
  -p 6333:6333 \
  -p 6334:6334 \
  -v qdrant_storage:/qdrant/storage \
  --restart unless-stopped \
  ollama-qwen3-embedding-0.6b:latest
```

#### 方式 B：使用 `docker compose`

```bash
docker compose up -d
```

如需启用 GPU，取消 [docker-compose.yml](docker-compose.yml) 中 `deploy.resources.reservations.devices` 段的注释后执行 `docker compose up -d`。

#### 常用运行时环境变量（可选）

| 变量名 | 默认值 | 说明 |
| --- | --- | --- |
| `OLLAMA_HOST` | `0.0.0.0:11434` | Ollama 服务监听地址与端口 |
| `OLLAMA_KEEP_ALIVE` | `-1` | 模型在内存中的保留时间，`-1` 表示常驻不卸载 |
| `OLLAMA_NUM_PARALLEL` | `1` | 并发处理请求数，高并发场景可调大（如 `4`） |
| `QDRANT__SERVICE__API_KEY` | 空 | 可选：为 Qdrant 开启 API Key 鉴权 |

---

## 二、API 调用示例

服务启动后，`qwen3-embedding:0.6b` 输出向量维度为 **1024**。

### 1. Ollama 原生接口（`/api/embed`）

```bash
curl http://localhost:11434/api/embed \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen3-embedding:0.6b",
    "input": ["你好，世界", "Qwen3 Embedding 模型离线部署"]
  }'
```

### 2. OpenAI 兼容接口（`/v1/embeddings`）

```bash
curl http://localhost:11434/v1/embeddings \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen3-embedding:0.6b",
    "input": "Hello world"
  }'
```

### 3. Qdrant 服务检查与创建集合

```bash
# 检查 Qdrant 就绪状态
curl http://localhost:6333/readyz

# 创建一个 1024 维（Cosine 距离）的向量集合
curl -X PUT http://localhost:6333/collections/docs \
  -H "Content-Type: application/json" \
  -d '{"vectors": {"size": 1024, "distance": "Cosine"}}'
```

浏览器访问 `http://localhost:6333/dashboard` 即可打开 Qdrant Web 管理界面。

### 4. Python（Embedding + 写入 Qdrant 检索）示例

```python
from openai import OpenAI
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, PointStruct, VectorParams

embed_client = OpenAI(base_url="http://localhost:11434/v1", api_key="ollama")
qdrant = QdrantClient(url="http://localhost:6333")

texts = ["Qwen3 Embedding 离线部署方案", "Qdrant 向量数据库检索"]
resp = embed_client.embeddings.create(model="qwen3-embedding:0.6b", input=texts)
vectors = [item.embedding for item in resp.data]

qdrant.recreate_collection(
    collection_name="docs",
    vectors_config=VectorParams(size=len(vectors[0]), distance=Distance.COSINE),
)
qdrant.upsert(
    collection_name="docs",
    points=[PointStruct(id=i, vector=v, payload={"text": t}) for i, (t, v) in enumerate(zip(texts, vectors))],
)
```

---

## 三、开发者构建与自动发布 Release

### 本地构建与打包

```bash
# 1. 拉取最新 ollama & qdrant 镜像并构建一体化镜像
./scripts/build.sh

# 2. 导出并分片打包到 dist/ 目录（每片 1800MB，附带 SHA256SUMS）
./scripts/package.sh
```

> **提示**：若本机开启了代理软件的 Fake-IP（如 DNS 返回 `198.18.x.x`）导致 `ollama pull` 触发 `redirect target not allowed` 校验拦截，可在构建时通过 `--add-host` 指定真实公网 IP 或配置 `HTTPS_PROXY`（同时设置 `NO_PROXY=127.0.0.1,localhost,0.0.0.0`）。

### GitHub Actions 自动构建发布

仓库已配置 [.github/workflows/release.yml](.github/workflows/release.yml)，推送 `v*` 格式标签即可自动在云端完成镜像构建、分片打包并发布到 GitHub Release：

```bash
git tag v1.0.0
git push origin v1.0.0
```
