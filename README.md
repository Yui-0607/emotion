# 见微 · 人生观察者

在线使用：[yui-0607.github.io/emotion](https://yui-0607.github.io/emotion/)

## 启动方法

双击 start.bat，然后浏览器打开 http://localhost:3000

## 目录结构

`
emotion/
├── public/
│   └── index.html    # 主页面（单文件应用）
├── server/
│   ├── server.ps1        # 基础服务器
│   └── server-proxy.ps1  # 带 API 代理的服务器（可选）
├── start.bat         # 一键启动
└── README.md
`

## 功能

- 每日记录：状态评分、情绪标签、自定义感受、日记
- AI 追问：每次记录后生成个性化追问
- 人生观察：手动触发 AI 深度分析长期记录
- 数据存储在浏览器的 localStorage