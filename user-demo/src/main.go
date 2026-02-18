package main

import (
	"bytes"
	"embed"
	"encoding/json"
	"fmt"
	"html/template"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
	"runtime"
	"strconv"
	"strings"
	"time"
)

//go:embed templates/*
var templatesFS embed.FS

const configFileName = "config.json"
const defaultPort = 8183

// Default configuration values
var defaultConfig = Config{
	ServerURL:  "",
	UserAPIKey: "",
	UserID:     0,
	Port:       defaultPort,
}

// Config holds the application configuration
type Config struct {
	ServerURL  string `json:"server_url"`   // Login service URL (e.g., https://login.example.com)
	UserAPIKey string `json:"user_api_key"` // Personal API key (from profile page)
	UserID     uint   `json:"user_id"`      // User ID (required for API authentication)
	Port       int    `json:"port"`         // Web server port (default: 8183)
}

// UserProfile represents the user profile from API
type UserProfile struct {
	ID            uint       `json:"id"`
	Email         string     `json:"email"`
	Username      string     `json:"username"`
	DisplayName   string     `json:"display_name"`
	Avatar        string     `json:"avatar"`
	Balance       float64    `json:"balance"`
	VIPLevel      int        `json:"vip_level"`
	VIPExpireAt   *time.Time `json:"vip_expire_at"`
	IsActive      bool       `json:"is_active"`
	LastLoginAt   *time.Time `json:"last_login_at"`
	CreatedAt     time.Time  `json:"created_at"`
	EmailVerified bool       `json:"email_verified"`
}

// UserBalance represents the user balance info
type UserBalance struct {
	Balance     float64    `json:"balance"`
	VIPLevel    int        `json:"vip_level"`
	VIPName     string     `json:"vip_name"`
	VIPExpireAt *time.Time `json:"vip_expire_at"`
}

// TokenResponse represents the token exchange response
type TokenResponse struct {
	AccessToken string `json:"access_token"`
	TokenType   string `json:"token_type"`
	ExpiresIn   int    `json:"expires_in"`
	UserID      uint   `json:"user_id"`
	Username    string `json:"username"`
	Email       string `json:"email"`
	DisplayName string `json:"display_name"`
}

// Message represents a user message
type Message struct {
	ID        uint       `json:"id"`
	Title     string     `json:"title"`
	Content   string     `json:"content"`
	Type      string     `json:"type"`
	IsRead    bool       `json:"is_read"`
	ReadAt    *time.Time `json:"read_at"`
	CreatedAt time.Time  `json:"created_at"`
}

// MessagesResponse represents messages list response
type MessagesResponse struct {
	Messages []Message `json:"messages"`
	Total    int64     `json:"total"`
	Page     int       `json:"page"`
	PageSize int       `json:"page_size"`
}

// UnreadCountResponse represents unread count response
type UnreadCountResponse struct {
	UnreadCount int64 `json:"unread_count"`
}

// BalanceLog represents a balance log entry
type BalanceLog struct {
	ID          uint      `json:"id"`
	Type        string    `json:"type"`
	Amount      float64   `json:"amount"`
	BalanceAfter float64  `json:"balance_after"`
	Description string    `json:"description"`
	CreatedAt   time.Time `json:"created_at"`
}

// BalanceLogsResponse represents balance logs response
type BalanceLogsResponse struct {
	Logs     []BalanceLog `json:"logs"`
	Total    int64        `json:"total"`
	Page     int          `json:"page"`
	PageSize int          `json:"page_size"`
}

// APIResponse represents a generic API response
type APIResponse struct {
	Success bool            `json:"success"`
	Message string          `json:"message,omitempty"`
	Data    json.RawMessage `json:"data,omitempty"`
}

// PageData holds data for template rendering
type PageData struct {
	Config       Config
	Profile      *UserProfile
	Balance      *UserBalance
	Token        *TokenResponse
	Error        string
	Success      string
	IsConfigured bool
	HasToken     bool
}

var config Config
var cachedToken string // Cache the JWT token for subsequent requests

func main() {
	// Load configuration
	config = loadConfig()

	// Setup HTTP handlers
	http.HandleFunc("/", handleHome)
	http.HandleFunc("/config", handleConfig)
	http.HandleFunc("/api/profile", handleAPIProfile)
	http.HandleFunc("/api/balance", handleAPIBalance)
	http.HandleFunc("/api/token", handleAPIToken)
	// JWT token authenticated endpoints
	http.HandleFunc("/api/jwt/profile", handleJWTProfile)
	http.HandleFunc("/api/jwt/messages", handleJWTMessages)
	http.HandleFunc("/api/jwt/unread-count", handleJWTUnreadCount)
	http.HandleFunc("/api/jwt/balance-logs", handleJWTBalanceLogs)
	http.HandleFunc("/api/jwt/update-profile", handleJWTUpdateProfile)
	http.HandleFunc("/api/jwt/balance", handleJWTBalance)
	http.HandleFunc("/api/jwt/third-party-status", handleJWTThirdPartyStatus)
	http.HandleFunc("/api/jwt/payment-orders", handleJWTPaymentOrders)
	http.HandleFunc("/api/jwt/read-all-messages", handleJWTReadAllMessages)
	// Browser login
	http.HandleFunc("/open-browser", handleOpenBrowser)
	http.HandleFunc("/api/token-status", handleTokenStatus)
	// Username/password login with captcha
	http.HandleFunc("/api/captcha/status", handleCaptchaStatus)
	http.HandleFunc("/api/captcha/generate", handleCaptchaGenerate)
	http.HandleFunc("/api/captcha/verify", handleCaptchaVerify)
	http.HandleFunc("/api/login", handleLogin)
	// Registration
	http.HandleFunc("/api/register", handleRegister)
	// VIP and Recharge related endpoints (public API)
	http.HandleFunc("/api/vip-levels", handleVIPLevels)
	http.HandleFunc("/api/recharge-settings", handleRechargeSettings)
	// VIP purchase and recharge (JWT authenticated)
	http.HandleFunc("/api/jwt/purchase-vip", handleJWTPurchaseVIP)
	http.HandleFunc("/api/jwt/recharge", handleJWTRecharge)

	port := config.Port
	if port == 0 {
		port = defaultPort
	}

	addr := fmt.Sprintf(":%d", port)
	fmt.Printf("========================================\n")
	fmt.Printf("  User API Web 示例程序\n")
	fmt.Printf("========================================\n")
	fmt.Printf("🌐 Web界面: http://localhost%s\n", addr)
	fmt.Printf("========================================\n")

	// Auto-open browser on Windows
	if runtime.GOOS == "windows" {
		go func() {
			time.Sleep(500 * time.Millisecond)
			openBrowser(fmt.Sprintf("http://localhost%s", addr))
		}()
	}

	log.Fatal(http.ListenAndServe(addr, nil))
}

// openBrowser opens the specified URL in the default browser
func openBrowser(url string) error {
	var cmd *exec.Cmd

	switch runtime.GOOS {
	case "windows":
		cmd = exec.Command("rundll32", "url.dll,FileProtocolHandler", url)
	case "darwin":
		cmd = exec.Command("open", url)
	case "linux":
		cmd = exec.Command("xdg-open", url)
	default:
		return fmt.Errorf("unsupported platform: %s", runtime.GOOS)
	}

	return cmd.Start()
}

// handleOpenBrowser opens the login page in browser
func handleOpenBrowser(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	if config.ServerURL == "" {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": false,
			"error":   "请先配置服务器地址",
		})
		return
	}

	target := r.URL.Query().Get("target")
	var url string
	switch target {
	case "login":
		url = config.ServerURL + "/login"
	case "profile":
		url = config.ServerURL + "/profile"
	case "register":
		url = config.ServerURL + "/register"
	default:
		url = config.ServerURL
	}

	if err := openBrowser(url); err != nil {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": false,
			"error":   "打开浏览器失败: " + err.Error(),
		})
		return
	}

	json.NewEncoder(w).Encode(map[string]interface{}{
		"success": true,
		"message": "已打开浏览器",
		"url":     url,
	})
}

// handleTokenStatus returns the current token status
func handleTokenStatus(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	json.NewEncoder(w).Encode(map[string]interface{}{
		"success":   true,
		"has_token": cachedToken != "",
	})
}

// loadConfig loads configuration from JSON file and environment variables
func loadConfig() Config {
	cfg := defaultConfig

	// Try to load from JSON file
	if data, err := os.ReadFile(configFileName); err == nil {
		if err := json.Unmarshal(data, &cfg); err != nil {
			log.Printf("警告: 解析配置文件 %s 失败: %v", configFileName, err)
		} else {
			log.Printf("已从 %s 加载配置", configFileName)
		}
	} else if os.IsNotExist(err) {
		// Generate default config file if it doesn't exist
		if err := generateDefaultConfig(); err != nil {
			log.Printf("警告: 生成默认配置文件失败: %v", err)
		} else {
			log.Printf("已生成默认配置文件 %s，请编辑该文件配置必要参数", configFileName)
		}
	}

	// Override with environment variables
	if serverURL := os.Getenv("SERVER_URL"); serverURL != "" {
		cfg.ServerURL = serverURL
	}
	if userAPIKey := os.Getenv("USER_API_KEY"); userAPIKey != "" {
		cfg.UserAPIKey = userAPIKey
	}
	if userIDStr := os.Getenv("USER_ID"); userIDStr != "" {
		if uid, err := strconv.ParseUint(userIDStr, 10, 32); err == nil {
			cfg.UserID = uint(uid)
		}
	}
	if portStr := os.Getenv("PORT"); portStr != "" {
		if p, err := strconv.Atoi(portStr); err == nil {
			cfg.Port = p
		}
	}

	// Normalize server URL (remove trailing slash)
	cfg.ServerURL = strings.TrimSuffix(cfg.ServerURL, "/")

	// Set default port if not specified
	if cfg.Port == 0 {
		cfg.Port = defaultPort
	}

	return cfg
}

// generateDefaultConfig generates a default config.json file
func generateDefaultConfig() error {
	data, err := json.MarshalIndent(defaultConfig, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(configFileName, data, 0600)
}

// saveConfig saves the current configuration to file
func saveConfig() error {
	data, err := json.MarshalIndent(config, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(configFileName, data, 0600)
}

// handleHome renders the main page
func handleHome(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}

	data := PageData{
		Config:       config,
		IsConfigured: config.ServerURL != "" && config.UserAPIKey != "" && config.UserID != 0,
		HasToken:     cachedToken != "",
	}

	renderTemplate(w, "index.html", data)
}

// handleConfig handles configuration updates
func handleConfig(w http.ResponseWriter, r *http.Request) {
	if r.Method == "POST" {
		config.ServerURL = strings.TrimSuffix(r.FormValue("server_url"), "/")
		config.UserAPIKey = r.FormValue("user_api_key")
		if uid, err := strconv.ParseUint(r.FormValue("user_id"), 10, 32); err == nil {
			config.UserID = uint(uid)
		}

		// Clear cached token when config changes
		cachedToken = ""

		if err := saveConfig(); err != nil {
			http.Error(w, "保存配置失败", http.StatusInternalServerError)
			return
		}

		http.Redirect(w, r, "/?success=config_saved", http.StatusSeeOther)
		return
	}

	http.Redirect(w, r, "/", http.StatusSeeOther)
}

// handleAPIProfile fetches and returns user profile
func handleAPIProfile(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	profile, err := fetchProfile()
	if err != nil {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": false,
			"error":   err.Error(),
		})
		return
	}

	json.NewEncoder(w).Encode(map[string]interface{}{
		"success": true,
		"data":    profile,
	})
}

// handleAPIBalance fetches and returns user balance
func handleAPIBalance(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	balance, err := fetchBalance()
	if err != nil {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": false,
			"error":   err.Error(),
		})
		return
	}

	json.NewEncoder(w).Encode(map[string]interface{}{
		"success": true,
		"data":    balance,
	})
}

// handleAPIToken exchanges API key for access token
func handleAPIToken(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	token, err := exchangeForToken()
	if err != nil {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": false,
			"error":   err.Error(),
		})
		return
	}

	// Cache the token for subsequent JWT requests
	cachedToken = token.AccessToken

	json.NewEncoder(w).Encode(map[string]interface{}{
		"success": true,
		"data":    token,
	})
}

// handleJWTProfile fetches profile using JWT token
func handleJWTProfile(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	if cachedToken == "" {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": false,
			"error":   "请先获取Token",
		})
		return
	}

	resp, err := makeJWTRequest("GET", "/api/auth/profile", nil)
	if err != nil {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": false,
			"error":   err.Error(),
		})
		return
	}

	var profile UserProfile
	if err := json.Unmarshal(resp.Data, &profile); err != nil {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": false,
			"error":   "解析响应失败: " + err.Error(),
		})
		return
	}

	json.NewEncoder(w).Encode(map[string]interface{}{
		"success": true,
		"data":    profile,
	})
}

// handleJWTMessages fetches messages using JWT token
func handleJWTMessages(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	if cachedToken == "" {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": false,
			"error":   "请先获取Token",
		})
		return
	}

	resp, err := makeJWTRequest("GET", "/api/messages?page=1&page_size=10", nil)
	if err != nil {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": false,
			"error":   err.Error(),
		})
		return
	}

	var messages MessagesResponse
	if err := json.Unmarshal(resp.Data, &messages); err != nil {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": false,
			"error":   "解析响应失败: " + err.Error(),
		})
		return
	}

	json.NewEncoder(w).Encode(map[string]interface{}{
		"success": true,
		"data":    messages,
	})
}

// handleJWTUnreadCount fetches unread message count using JWT token
func handleJWTUnreadCount(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	if cachedToken == "" {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": false,
			"error":   "请先获取Token",
		})
		return
	}

	resp, err := makeJWTRequest("GET", "/api/messages/unread-count", nil)
	if err != nil {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": false,
			"error":   err.Error(),
		})
		return
	}

	var unread UnreadCountResponse
	if err := json.Unmarshal(resp.Data, &unread); err != nil {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": false,
			"error":   "解析响应失败: " + err.Error(),
		})
		return
	}

	json.NewEncoder(w).Encode(map[string]interface{}{
		"success": true,
		"data":    unread,
	})
}

// handleJWTBalanceLogs fetches balance logs using JWT token
func handleJWTBalanceLogs(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	if cachedToken == "" {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": false,
			"error":   "请先获取Token",
		})
		return
	}

	resp, err := makeJWTRequest("GET", "/api/auth/user-logs/balance?page=1&page_size=10", nil)
	if err != nil {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": false,
			"error":   err.Error(),
		})
		return
	}

	var logs BalanceLogsResponse
	if err := json.Unmarshal(resp.Data, &logs); err != nil {
		// Return raw data if parsing fails
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": true,
			"data":    json.RawMessage(resp.Data),
		})
		return
	}

	json.NewEncoder(w).Encode(map[string]interface{}{
		"success": true,
		"data":    logs,
	})
}

// handleJWTUpdateProfile updates user profile using JWT token
func handleJWTUpdateProfile(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	if r.Method != "POST" {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": false,
			"error":   "Method not allowed",
		})
		return
	}

	if cachedToken == "" {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": false,
			"error":   "请先获取Token",
		})
		return
	}

	// Parse request body
	var updateData map[string]string
	if err := json.NewDecoder(r.Body).Decode(&updateData); err != nil {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": false,
			"error":   "Invalid request body",
		})
		return
	}

	resp, err := makeJWTRequest("PUT", "/api/auth/profile", updateData)
	if err != nil {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": false,
			"error":   err.Error(),
		})
		return
	}

	json.NewEncoder(w).Encode(map[string]interface{}{
		"success": true,
		"message": resp.Message,
		"data":    json.RawMessage(resp.Data),
	})
}

// handleJWTBalance fetches user balance using JWT token
func handleJWTBalance(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	if cachedToken == "" {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": false,
			"error":   "请先获取Token",
		})
		return
	}

	resp, err := makeJWTRequest("GET", "/api/auth/balance", nil)
	if err != nil {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": false,
			"error":   err.Error(),
		})
		return
	}

	json.NewEncoder(w).Encode(map[string]interface{}{
		"success": true,
		"data":    json.RawMessage(resp.Data),
	})
}

// handleJWTThirdPartyStatus fetches third-party binding status using JWT token
func handleJWTThirdPartyStatus(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	if cachedToken == "" {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": false,
			"error":   "请先获取Token",
		})
		return
	}

	resp, err := makeJWTRequest("GET", "/api/auth/third-party-status", nil)
	if err != nil {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": false,
			"error":   err.Error(),
		})
		return
	}

	json.NewEncoder(w).Encode(map[string]interface{}{
		"success": true,
		"data":    json.RawMessage(resp.Data),
	})
}

// handleJWTPaymentOrders fetches payment orders using JWT token
func handleJWTPaymentOrders(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	if cachedToken == "" {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": false,
			"error":   "请先获取Token",
		})
		return
	}

	resp, err := makeJWTRequest("GET", "/api/auth/user-logs/payment-orders?page=1&page_size=10", nil)
	if err != nil {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": false,
			"error":   err.Error(),
		})
		return
	}

	json.NewEncoder(w).Encode(map[string]interface{}{
		"success": true,
		"data":    json.RawMessage(resp.Data),
	})
}

// handleJWTReadAllMessages marks all messages as read using JWT token
func handleJWTReadAllMessages(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	if cachedToken == "" {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": false,
			"error":   "请先获取Token",
		})
		return
	}

	resp, err := makeJWTRequest("POST", "/api/messages/read-all", nil)
	if err != nil {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": false,
			"error":   err.Error(),
		})
		return
	}

	json.NewEncoder(w).Encode(map[string]interface{}{
		"success": true,
		"message": resp.Message,
	})
}

// makeAPIRequest makes an authenticated API request using API Key
func makeAPIRequest(method, endpoint string) (*APIResponse, error) {
	if config.ServerURL == "" {
		return nil, fmt.Errorf("服务器地址未配置")
	}
	if config.UserAPIKey == "" {
		return nil, fmt.Errorf("API密钥未配置")
	}
	if config.UserID == 0 {
		return nil, fmt.Errorf("用户ID未配置")
	}

	url := config.ServerURL + endpoint

	req, err := http.NewRequest(method, url, nil)
	if err != nil {
		return nil, fmt.Errorf("创建请求失败: %v", err)
	}

	// Set required headers (both API Key and User ID)
	req.Header.Set("X-User-API-Key", config.UserAPIKey)
	req.Header.Set("X-User-ID", strconv.FormatUint(uint64(config.UserID), 10))
	req.Header.Set("Accept", "application/json")

	client := &http.Client{
		Timeout: 30 * time.Second,
	}

	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("请求失败: %v", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("读取响应失败: %v", err)
	}

	var apiResp APIResponse
	if err := json.Unmarshal(body, &apiResp); err != nil {
		return nil, fmt.Errorf("解析响应失败: %v, body: %s", err, string(body))
	}

	if !apiResp.Success {
		return nil, fmt.Errorf("API错误: %s", apiResp.Message)
	}

	return &apiResp, nil
}

// makeJWTRequest makes an authenticated API request using JWT token
func makeJWTRequest(method, endpoint string, body interface{}) (*APIResponse, error) {
	if config.ServerURL == "" {
		return nil, fmt.Errorf("服务器地址未配置")
	}
	if cachedToken == "" {
		return nil, fmt.Errorf("JWT Token未获取")
	}

	url := config.ServerURL + endpoint

	var reqBody io.Reader
	if body != nil {
		jsonBody, err := json.Marshal(body)
		if err != nil {
			return nil, fmt.Errorf("序列化请求体失败: %v", err)
		}
		reqBody = bytes.NewReader(jsonBody)
	}

	req, err := http.NewRequest(method, url, reqBody)
	if err != nil {
		return nil, fmt.Errorf("创建请求失败: %v", err)
	}

	// Set JWT Authorization header
	req.Header.Set("Authorization", "Bearer "+cachedToken)
	req.Header.Set("Accept", "application/json")
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}

	client := &http.Client{
		Timeout: 30 * time.Second,
	}

	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("请求失败: %v", err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("读取响应失败: %v", err)
	}

	var apiResp APIResponse
	if err := json.Unmarshal(respBody, &apiResp); err != nil {
		return nil, fmt.Errorf("解析响应失败: %v, body: %s", err, string(respBody))
	}

	if !apiResp.Success {
		return nil, fmt.Errorf("API错误: %s", apiResp.Message)
	}

	return &apiResp, nil
}

// fetchProfile fetches the user profile
func fetchProfile() (*UserProfile, error) {
	resp, err := makeAPIRequest("GET", "/api/user-api/profile")
	if err != nil {
		return nil, err
	}

	var profile UserProfile
	if err := json.Unmarshal(resp.Data, &profile); err != nil {
		return nil, fmt.Errorf("解析用户资料失败: %v", err)
	}

	return &profile, nil
}

// fetchBalance fetches the user balance
func fetchBalance() (*UserBalance, error) {
	resp, err := makeAPIRequest("GET", "/api/user-api/balance")
	if err != nil {
		return nil, err
	}

	var balance UserBalance
	if err := json.Unmarshal(resp.Data, &balance); err != nil {
		return nil, fmt.Errorf("解析余额信息失败: %v", err)
	}

	return &balance, nil
}

// exchangeForToken exchanges API key for JWT access token
func exchangeForToken() (*TokenResponse, error) {
	resp, err := makeAPIRequest("POST", "/api/user-api/token")
	if err != nil {
		return nil, err
	}

	var token TokenResponse
	if err := json.Unmarshal(resp.Data, &token); err != nil {
		return nil, fmt.Errorf("解析令牌失败: %v", err)
	}

	return &token, nil
}

// renderTemplate renders an HTML template
func renderTemplate(w http.ResponseWriter, name string, data interface{}) {
	tmpl := template.Must(template.ParseFS(templatesFS, "templates/"+name))
	if err := tmpl.Execute(w, data); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
	}
}

// makePublicRequest makes a public API request (no auth required)
func makePublicRequest(method, endpoint string, body interface{}) (*APIResponse, error) {
	if config.ServerURL == "" {
		return nil, fmt.Errorf("服务器地址未配置")
	}

	url := config.ServerURL + endpoint

	var reqBody io.Reader
	if body != nil {
		jsonBody, err := json.Marshal(body)
		if err != nil {
			return nil, fmt.Errorf("序列化请求体失败: %v", err)
		}
		reqBody = bytes.NewReader(jsonBody)
	}

	req, err := http.NewRequest(method, url, reqBody)
	if err != nil {
		return nil, fmt.Errorf("创建请求失败: %v", err)
	}

	req.Header.Set("Accept", "application/json")
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}

	client := &http.Client{
		Timeout: 30 * time.Second,
	}

	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("请求失败: %v", err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("读取响应失败: %v", err)
	}

	var apiResp APIResponse
	if err := json.Unmarshal(respBody, &apiResp); err != nil {
		return nil, fmt.Errorf("解析响应失败: %v, body: %s", err, string(respBody))
	}

	return &apiResp, nil
}

// handleCaptchaStatus gets captcha status from server
func handleCaptchaStatus(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	resp, err := makePublicRequest("GET", "/api/captcha/status", nil)
	if err != nil {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": false,
			"error":   err.Error(),
		})
		return
	}

	json.NewEncoder(w).Encode(map[string]interface{}{
		"success": true,
		"data":    json.RawMessage(resp.Data),
	})
}

// handleCaptchaGenerate generates a new captcha
func handleCaptchaGenerate(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	resp, err := makePublicRequest("POST", "/api/captcha/generate", nil)
	if err != nil {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": false,
			"error":   err.Error(),
		})
		return
	}

	json.NewEncoder(w).Encode(map[string]interface{}{
		"success": true,
		"data":    json.RawMessage(resp.Data),
	})
}

// handleCaptchaVerify verifies a captcha
func handleCaptchaVerify(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	if r.Method != "POST" {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": false,
			"error":   "Method not allowed",
		})
		return
	}

	// Parse request body
	var verifyData map[string]interface{}
	if err := json.NewDecoder(r.Body).Decode(&verifyData); err != nil {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": false,
			"error":   "Invalid request body",
		})
		return
	}

	resp, err := makePublicRequest("POST", "/api/captcha/verify", verifyData)
	if err != nil {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": false,
			"error":   err.Error(),
		})
		return
	}

	json.NewEncoder(w).Encode(map[string]interface{}{
		"success": resp.Success,
		"message": resp.Message,
		"data":    json.RawMessage(resp.Data),
	})
}

// handleLogin handles username/password login with captcha
func handleLogin(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	if r.Method != "POST" {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": false,
			"error":   "Method not allowed",
		})
		return
	}

	// Parse request body
	var loginData map[string]interface{}
	if err := json.NewDecoder(r.Body).Decode(&loginData); err != nil {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": false,
			"error":   "Invalid request body",
		})
		return
	}

	resp, err := makePublicRequest("POST", "/api/auth/login", loginData)
	if err != nil {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": false,
			"error":   err.Error(),
		})
		return
	}

	// If login successful, extract and cache the token
	if resp.Success && resp.Data != nil {
		var loginResp struct {
			Token string `json:"token"`
			User  struct {
				ID          uint   `json:"id"`
				Username    string `json:"username"`
				Email       string `json:"email"`
				DisplayName string `json:"display_name"`
			} `json:"user"`
		}
		if err := json.Unmarshal(resp.Data, &loginResp); err == nil && loginResp.Token != "" {
			cachedToken = loginResp.Token
			// Update config with user ID
			config.UserID = loginResp.User.ID
		}
	}

	json.NewEncoder(w).Encode(map[string]interface{}{
		"success": resp.Success,
		"message": resp.Message,
		"data":    json.RawMessage(resp.Data),
	})
}

// handleRegister handles user registration with captcha
func handleRegister(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	if r.Method != "POST" {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": false,
			"error":   "Method not allowed",
		})
		return
	}

	// Parse request body
	var registerData map[string]interface{}
	if err := json.NewDecoder(r.Body).Decode(&registerData); err != nil {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": false,
			"error":   "Invalid request body",
		})
		return
	}

	resp, err := makePublicRequest("POST", "/api/auth/register", registerData)
	if err != nil {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": false,
			"error":   err.Error(),
		})
		return
	}

	// If registration successful, extract and cache the token
	if resp.Success && resp.Data != nil {
		var registerResp struct {
			Token string `json:"token"`
			User  struct {
				ID          uint   `json:"id"`
				Username    string `json:"username"`
				Email       string `json:"email"`
				DisplayName string `json:"display_name"`
			} `json:"user"`
		}
		if err := json.Unmarshal(resp.Data, &registerResp); err == nil && registerResp.Token != "" {
			cachedToken = registerResp.Token
			// Update config with user ID
			config.UserID = registerResp.User.ID
		}
	}

	json.NewEncoder(w).Encode(map[string]interface{}{
		"success": resp.Success,
		"message": resp.Message,
		"data":    json.RawMessage(resp.Data),
	})
}

// handleVIPLevels gets available VIP levels from public API
func handleVIPLevels(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	resp, err := makePublicRequest("GET", "/api/vip-levels", nil)
	if err != nil {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": false,
			"error":   err.Error(),
		})
		return
	}

	json.NewEncoder(w).Encode(map[string]interface{}{
		"success": true,
		"data":    json.RawMessage(resp.Data),
	})
}

// handleRechargeSettings gets recharge settings from public API
func handleRechargeSettings(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	resp, err := makePublicRequest("GET", "/api/recharge-settings", nil)
	if err != nil {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": false,
			"error":   err.Error(),
		})
		return
	}

	json.NewEncoder(w).Encode(map[string]interface{}{
		"success": true,
		"data":    json.RawMessage(resp.Data),
	})
}

// handleJWTPurchaseVIP handles VIP purchase using JWT token
func handleJWTPurchaseVIP(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	if r.Method != "POST" {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": false,
			"error":   "Method not allowed",
		})
		return
	}

	if cachedToken == "" {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": false,
			"error":   "请先获取Token",
		})
		return
	}

	// Parse request body
	var purchaseData map[string]interface{}
	if err := json.NewDecoder(r.Body).Decode(&purchaseData); err != nil {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": false,
			"error":   "Invalid request body",
		})
		return
	}

	// Set product_type to "vip"
	purchaseData["product_type"] = "vip"

	resp, err := makeJWTRequest("POST", "/api/payment/create", purchaseData)
	if err != nil {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": false,
			"error":   err.Error(),
		})
		return
	}

	json.NewEncoder(w).Encode(map[string]interface{}{
		"success": true,
		"message": resp.Message,
		"data":    json.RawMessage(resp.Data),
	})
}

// handleJWTRecharge handles balance recharge using JWT token
func handleJWTRecharge(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	if r.Method != "POST" {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": false,
			"error":   "Method not allowed",
		})
		return
	}

	if cachedToken == "" {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": false,
			"error":   "请先获取Token",
		})
		return
	}

	// Parse request body
	var rechargeData map[string]interface{}
	if err := json.NewDecoder(r.Body).Decode(&rechargeData); err != nil {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": false,
			"error":   "Invalid request body",
		})
		return
	}

	// Set product_type to "recharge"
	rechargeData["product_type"] = "recharge"

	resp, err := makeJWTRequest("POST", "/api/payment/create", rechargeData)
	if err != nil {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": false,
			"error":   err.Error(),
		})
		return
	}

	json.NewEncoder(w).Encode(map[string]interface{}{
		"success": true,
		"message": resp.Message,
		"data":    json.RawMessage(resp.Data),
	})
}
