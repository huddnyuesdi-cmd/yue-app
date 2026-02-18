# User API Web 示例程序

这是一个使用 `/api/user-api` 接口获取用户信息的 **Web 版本**示例程序。

## 功能特性

- 🌐 Web 界面操作，默认端口 8183
- 🔐 使用个人 API 密钥 + 用户ID 认证
- 📋 获取用户资料信息
- 💰 查询账户余额和 VIP 等级
- 🎫 获取 JWT 访问令牌（用于直接登录）
- 📬 使用 JWT Token 获取消息列表
- 📊 使用 JWT Token 获取余额变动记录
- 🖥️ Windows 自动打开浏览器
- 🔗 一键打开登录/注册页面
- 📝 用户注册演示（支持验证码）

## Windows 自动打开浏览器

在 Windows 系统上运行时，程序会自动打开默认浏览器访问 Web 界面。

## 配置方法

### 方法一：Web 界面配置

1. 启动程序后访问 `http://localhost:8183`
2. 在配置设置区域填写：
   - 服务器地址（例如 `https://login.example.com`）
   - 用户ID（您的用户ID）
   - API 密钥（从个人资料页面获取）
3. 点击"保存配置"

### 方法二：JSON 配置文件

首次运行时会自动生成 `config.json` 配置文件，编辑该文件：

```json
{
  "server_url": "https://your-login-service.com",
  "user_api_key": "your-personal-api-key",
  "user_id": 12345,
  "port": 8183
}
```

配置说明：
- `server_url`: 登录服务的地址（例如 `https://login.example.com`）
- `user_api_key`: 个人 API 密钥（从用户资料页面获取）
- `user_id`: 您的用户ID（**必填**，用于API认证）
- `port`: Web 服务器端口（默认 8183）

### 方法三：环境变量

也可以通过环境变量配置（优先级高于配置文件）：

```bash
export SERVER_URL="https://your-login-service.com"
export USER_API_KEY="your-personal-api-key"
export USER_ID="12345"
export PORT="8183"
./demo_user_api
```

## 使用方法

### 本地运行

```bash
cd demo_user_api
go run main.go
```

### 编译运行

```bash
cd demo_user_api
go build -o demo_user_api main.go
./demo_user_api
```

然后访问 `http://localhost:8183`

## 获取 API 密钥和用户ID

1. 登录到 Common Login Service
2. 进入个人资料页面 (`/profile`)
3. 查看您的用户ID
4. 在 "API 密钥" 区域生成或复制您的 API 密钥

## API 端点说明

### 公开端点（无需认证）

| 端点 | 方法 | 说明 |
|------|------|------|
| `/api/auth/register` | POST | 用户注册 |
| `/api/auth/login` | POST | 用户登录 |
| `/api/captcha/status` | GET | 获取验证码状态 |
| `/api/captcha/generate` | POST | 生成验证码 |
| `/api/captcha/verify` | POST | 验证验证码 |

### API Key 认证端点

使用 `X-User-API-Key` 和 `X-User-ID` Header 认证：

| 端点 | 方法 | 说明 |
|------|------|------|
| `/api/user-api/profile` | GET | 获取用户资料 |
| `/api/user-api/balance` | GET | 获取余额和VIP信息 |
| `/api/user-api/token` | POST | 获取JWT访问令牌 |

### JWT Token 认证端点

使用 `Authorization: Bearer {token}` Header 认证：

| 端点 | 方法 | 说明 |
|------|------|------|
| `/api/auth/profile` | GET | 获取用户资料 |
| `/api/auth/profile` | PUT | 更新用户资料 |
| `/api/messages` | GET | 获取消息列表 |
| `/api/messages/unread-count` | GET | 获取未读消息数 |
| `/api/auth/user-logs/balance` | GET | 获取余额变动记录 |

### 认证方式

#### API Key 认证
所有请求需要在 HTTP Header 中携带以下两个参数：

- `X-User-API-Key`: 您的个人API密钥
- `X-User-ID`: 您的用户ID

示例：
```bash
curl -X GET "https://login.example.com/api/user-api/profile" \
  -H "X-User-API-Key: your-api-key" \
  -H "X-User-ID: 12345"
```

#### JWT Token 认证

获取 Token 后使用 Bearer 认证：

```bash
curl -X GET "https://login.example.com/api/messages" \
  -H "Authorization: Bearer your-jwt-token"
```

### 获取 JWT Token

通过 `/api/user-api/token` 端点，您可以用 API 密钥换取 JWT 访问令牌：

```bash
curl -X POST "https://login.example.com/api/user-api/token" \
  -H "X-User-API-Key: your-api-key" \
  -H "X-User-ID: 12345"
```

返回的 JWT token 可以用于其他需要 Bearer 认证的接口。

### 用户注册

通过 `/api/auth/register` 端点注册新用户：

```bash
curl -X POST "https://login.example.com/api/auth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "username": "johndoe",
    "password": "password123",
    "display_name": "John Doe",
    "captcha_id": "abc123",
    "captcha_position": 150
  }'
```

注册成功后会返回 JWT token，可直接用于后续认证请求。

## 许可证

与主项目 Common-LoginService 使用相同的许可证。
