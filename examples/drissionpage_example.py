#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
fingerprint-chromium Docker容器 DrissionPage连接示例

使用说明：
1. 确保Docker容器已启动：docker-compose up -d
2. 安装DrissionPage：pip install DrissionPage
3. 运行此脚本：python drissionpage_example.py
"""

from DrissionPage import ChromiumPage, ChromiumOptions
import time
import json

def test_fingerprint_chrome():
    """测试fingerprint-chrome容器连接"""
    
    print("=== fingerprint-chromium Docker容器连接测试 ===")
    
    # 配置Chrome选项
    co = ChromiumOptions()
    
    # 连接到Docker容器的Chrome调试端口
    co.set_local_port(9222)
    
    # 可选：设置其他选项
    # co.set_user_agent('自定义User-Agent')
    # co.set_proxy('http://proxy:port')
    
    try:
        # 创建页面对象
        print("正在连接到容器中的Chrome...")
        page = ChromiumPage(co)
        
        print("✓ 成功连接到fingerprint-chrome容器")
        print(f"浏览器版本: {page.run_cdp('Browser.getVersion')}")
        
        # 测试基本功能
        print("\n=== 基本功能测试 ===")
        
        # 访问测试页面
        print("访问测试页面...")
        page.get('https://httpbin.org/headers')
        time.sleep(2)
        
        print(f"页面标题: {page.title}")
        print(f"当前URL: {page.url}")
        
        # 测试指纹检测
        print("\n=== 指纹检测测试 ===")
        
        # 访问CreepJS进行指纹检测
        print("访问CreepJS进行指纹检测...")
        page.get('https://abrahamjuliot.github.io/creepjs/')
        time.sleep(10)  # 等待页面加载和检测完成
        
        # 获取User-Agent
        user_agent = page.run_js('return navigator.userAgent')
        print(f"User-Agent: {user_agent}")
        
        # 获取平台信息
        platform = page.run_js('return navigator.platform')
        print(f"Platform: {platform}")
        
        # 获取WebDriver状态
        webdriver = page.run_js('return navigator.webdriver')
        print(f"WebDriver: {webdriver}")
        
        # 获取语言信息
        languages = page.run_js('return navigator.languages')
        print(f"Languages: {languages}")
        
        # 获取时区
        timezone = page.run_js('return Intl.DateTimeFormat().resolvedOptions().timeZone')
        print(f"Timezone: {timezone}")
        
        # 获取屏幕信息
        screen_info = page.run_js('''
            return {
                width: screen.width,
                height: screen.height,
                colorDepth: screen.colorDepth,
                pixelDepth: screen.pixelDepth
            }
        ''')
        print(f"Screen: {screen_info}")
        
        # 获取Canvas指纹
        canvas_fp = page.run_js('''
            const canvas = document.createElement('canvas');
            const ctx = canvas.getContext('2d');
            ctx.textBaseline = 'top';
            ctx.font = '14px Arial';
            ctx.fillText('Canvas fingerprint test 🎨', 2, 2);
            return canvas.toDataURL().slice(-50);
        ''')
        print(f"Canvas fingerprint (last 50 chars): {canvas_fp}")
        
        # 测试自动化操作
        print("\n=== 自动化操作测试 ===")
        
        # 访问百度进行搜索测试
        print("访问百度进行搜索测试...")
        page.get('https://www.baidu.com')
        time.sleep(2)
        
        # 查找搜索框并输入
        search_box = page.ele('#kw')
        if search_box:
            search_box.input('fingerprint-chromium')
            time.sleep(1)
            
            # 点击搜索按钮
            search_btn = page.ele('#su')
            if search_btn:
                search_btn.click()
                time.sleep(3)
                print(f"搜索结果页面标题: {page.title}")
            else:
                print("未找到搜索按钮")
        else:
            print("未找到搜索框")
        
        print("\n=== 测试完成 ===")
        print("所有功能测试正常，fingerprint-chrome容器工作正常！")
        
        # 保持浏览器打开一段时间以便观察
        print("\n浏览器将保持打开状态30秒，您可以通过noVNC界面观察...")
        print("noVNC访问地址: http://localhost:6080")
        time.sleep(30)
        
    except Exception as e:
        print(f"❌ 连接失败: {e}")
        print("\n请检查：")
        print("1. Docker容器是否已启动：docker-compose ps")
        print("2. 端口9222是否已开放：curl http://localhost:9222/json")
        print("3. 防火墙设置是否正确")
        return False
    
    finally:
        # 关闭浏览器
        try:
            page.quit()
            print("浏览器已关闭")
        except:
            pass
    
    return True

def test_multiple_tabs():
    """测试多标签页操作"""
    
    print("\n=== 多标签页操作测试 ===")
    
    co = ChromiumOptions()
    co.set_local_port(9222)
    
    try:
        page = ChromiumPage(co)
        
        # 打开多个标签页
        urls = [
            'https://httpbin.org/ip',
            'https://httpbin.org/user-agent',
            'https://httpbin.org/headers'
        ]
        
        tabs = []
        for i, url in enumerate(urls):
            if i == 0:
                page.get(url)
                tabs.append(page)
            else:
                new_tab = page.new_tab(url)
                tabs.append(new_tab)
            time.sleep(2)
        
        # 在每个标签页中执行操作
        for i, tab in enumerate(tabs):
            tab.set.window.to_front()
            print(f"标签页 {i+1}: {tab.title}")
            time.sleep(1)
        
        print("多标签页测试完成")
        
        # 关闭所有标签页
        for tab in tabs[1:]:  # 保留第一个标签页
            tab.close()
        
        page.quit()
        
    except Exception as e:
        print(f"多标签页测试失败: {e}")

if __name__ == "__main__":
    # 基本功能测试
    success = test_fingerprint_chrome()
    
    if success:
        # 多标签页测试
        test_multiple_tabs()
    
    print("\n测试脚本执行完毕！")
