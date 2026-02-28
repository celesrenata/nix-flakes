#!/usr/bin/env python3
"""
Test script for OpenAI DALL-E MCP Server
This script tests the server functionality without requiring stdio connections.
"""

import asyncio
import os
import sys
from server import server, get_openai_client

async def test_server():
    """Test the MCP server functionality."""
    print("Testing OpenAI DALL-E MCP Server...")
    print("=" * 50)
    
    # Test 1: Check OpenAI API key
    try:
        api_key = os.getenv("OPENAI_API_KEY")
        if not api_key:
            print("❌ OPENAI_API_KEY not set")
            print("Please set your OpenAI API key: export OPENAI_API_KEY=your_key_here")
            return False
        else:
            print("✅ OPENAI_API_KEY is set")
    except Exception as e:
        print(f"❌ Error checking API key: {e}")
        return False
    
    # Test 2: Test OpenAI client initialization
    try:
        client = get_openai_client()
        print("✅ OpenAI client initialized successfully")
    except Exception as e:
        print(f"❌ Error initializing OpenAI client: {e}")
        return False
    
    # Test 3: List resources
    try:
        resources = await server.list_resources()
        print(f"✅ Resources available: {len(resources)}")
        for resource in resources:
            print(f"   - {resource.name}: {resource.description}")
    except Exception as e:
        print(f"❌ Error listing resources: {e}")
        return False
    
    # Test 4: List tools
    try:
        tools = await server.list_tools()
        print(f"✅ Tools available: {len(tools)}")
        for tool in tools:
            print(f"   - {tool.name}: {tool.description}")
    except Exception as e:
        print(f"❌ Error listing tools: {e}")
        return False
    
    # Test 5: Read resource
    try:
        from pydantic import AnyUrl
        info = await server.read_resource(AnyUrl("dalle://info"))
        print("✅ Resource reading works")
        print("   Resource content preview:", info[:100] + "..." if len(info) > 100 else info)
    except Exception as e:
        print(f"❌ Error reading resource: {e}")
        return False
    
    print("\n" + "=" * 50)
    print("✅ All basic tests passed!")
    print("The MCP server is ready for use with Amazon Q CLI.")
    print("\nTo configure with Q CLI, run:")
    print(f"q configure add-mcp-server openai-dalle {os.path.dirname(os.path.abspath(__file__))}/start-server.sh")
    
    return True

if __name__ == "__main__":
    success = asyncio.run(test_server())
    sys.exit(0 if success else 1)
