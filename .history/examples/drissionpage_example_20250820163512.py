#!/usr/bin/env python3
"""
Example script showing how to use DrissionPage with the fingerprint-chromium Docker container.

Prerequisites:
1. Start the Docker container:
   docker run -d --name fpc -p 9222:9222 -p 6081:6081 yourname/fingerprint-chromium-drission:latest

2. Install DrissionPage:
   pip install DrissionPage

3. Run this script:
   python drissionpage_example.py
"""

from DrissionPage import Chromium
import time

def main():
    print("Connecting to fingerprint-chromium container...")
    
    try:
        # Connect to the running container's CDP endpoint
        c = Chromium(address='127.0.0.1', port=9222)
        print("✓ Connected successfully!")
        
        # Get the current tab or create a new one
        tab = c.get_tab()
        if not tab:
            tab = c.new_tab()
        
        print("Navigating to test page...")
        tab.get('https://httpbin.org/headers')
        
        print(f"Page title: {tab.title}")
        print(f"Current URL: {tab.url}")
        
        # Test fingerprint features
        print("\nTesting fingerprint features...")
        
        # Navigate to a fingerprint testing site
        tab.get('https://abrahamjuliot.github.io/creepjs/')
        time.sleep(3)  # Wait for page to load
        
        print(f"CreepJS page title: {tab.title}")
        
        # You can also test with browserleaks.com
        tab.get('https://browserleaks.com/javascript')
        time.sleep(3)
        
        print(f"BrowserLeaks page title: {tab.title}")
        
        # Example of interacting with elements
        print("\nTesting element interaction...")
        tab.get('https://httpbin.org/forms/post')
        
        # Fill a form (if elements exist)
        try:
            custname_input = tab.ele('input[name="custname"]')
            if custname_input:
                custname_input.input('Test User')
                print("✓ Form field filled")
        except Exception as e:
            print(f"Form interaction: {e}")
        
        print("\n✓ All tests completed successfully!")
        print("You can view the browser in real-time at: http://localhost:6080")
        
    except Exception as e:
        print(f"❌ Error: {e}")
        print("Make sure the Docker container is running on port 9222")
        print("Run: docker run -d --name fpc -p 9222:9222 -p 6080:6080 yourname/fingerprint-chromium-drission:latest")

if __name__ == "__main__":
    main()
