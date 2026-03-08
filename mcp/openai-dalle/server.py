#!/usr/bin/env python3
"""
OpenAI DALL-E MCP Server

This MCP server provides image generation capabilities using OpenAI's DALL-E API.
"""

import asyncio
import base64
import os
from typing import Any, Sequence
import logging

from mcp.server.models import InitializationOptions
from mcp.server import NotificationOptions, Server
from mcp.types import (
    Resource,
    Tool,
    TextContent,
    ImageContent,
    EmbeddedResource,
)
from pydantic import AnyUrl
import mcp.types as types
from openai import OpenAI

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("dalle-mcp")

# Initialize OpenAI client
client = None

def get_openai_client():
    """Get OpenAI client, initializing if needed."""
    global client
    if client is None:
        api_key = os.getenv("OPENAI_API_KEY")
        if not api_key:
            raise ValueError("OPENAI_API_KEY environment variable is required")
        client = OpenAI(api_key=api_key)
    return client

# Create a server instance
server = Server("dalle-mcp")

@server.list_resources()
async def handle_list_resources() -> list[Resource]:
    """List available resources."""
    return [
        Resource(
            uri=AnyUrl("dalle://info"),
            name="DALL-E Info",
            description="Information about DALL-E image generation capabilities",
            mimeType="text/plain",
        )
    ]

@server.read_resource()
async def handle_read_resource(uri: AnyUrl) -> str:
    """Read a specific resource."""
    if str(uri) == "dalle://info":
        return """DALL-E Image Generation MCP Server

This server provides access to OpenAI's DALL-E image generation API.

Available tools:
- generate_image: Generate images from text descriptions
- edit_image: Edit existing images with text prompts
- create_variation: Create variations of existing images

Requirements:
- OPENAI_API_KEY environment variable must be set
- Valid OpenAI API subscription with DALL-E access

Supported image formats: PNG, JPEG
Maximum image size: 1024x1024 pixels
"""
    else:
        raise ValueError(f"Unknown resource: {uri}")

@server.list_tools()
async def handle_list_tools() -> list[Tool]:
    """List available tools."""
    return [
        Tool(
            name="generate_image",
            description="Generate an image from a text description using DALL-E",
            inputSchema={
                "type": "object",
                "properties": {
                    "prompt": {
                        "type": "string",
                        "description": "Text description of the image to generate"
                    },
                    "size": {
                        "type": "string",
                        "enum": ["256x256", "512x512", "1024x1024"],
                        "default": "1024x1024",
                        "description": "Size of the generated image"
                    },
                    "quality": {
                        "type": "string",
                        "enum": ["standard", "hd"],
                        "default": "standard",
                        "description": "Quality of the generated image"
                    },
                    "style": {
                        "type": "string",
                        "enum": ["vivid", "natural"],
                        "default": "vivid",
                        "description": "Style of the generated image"
                    }
                },
                "required": ["prompt"]
            }
        ),
        Tool(
            name="create_variation",
            description="Create variations of an existing image",
            inputSchema={
                "type": "object",
                "properties": {
                    "image_path": {
                        "type": "string",
                        "description": "Path to the source image file"
                    },
                    "n": {
                        "type": "integer",
                        "minimum": 1,
                        "maximum": 10,
                        "default": 1,
                        "description": "Number of variations to generate"
                    },
                    "size": {
                        "type": "string",
                        "enum": ["256x256", "512x512", "1024x1024"],
                        "default": "1024x1024",
                        "description": "Size of the generated variations"
                    }
                },
                "required": ["image_path"]
            }
        )
    ]

@server.call_tool()
async def handle_call_tool(name: str, arguments: dict | None) -> list[types.TextContent | types.ImageContent | types.EmbeddedResource]:
    """Handle tool calls."""
    if arguments is None:
        arguments = {}

    try:
        openai_client = get_openai_client()
        
        if name == "generate_image":
            prompt = arguments.get("prompt")
            if not prompt:
                raise ValueError("prompt is required")
            
            size = arguments.get("size", "1024x1024")
            quality = arguments.get("quality", "standard")
            style = arguments.get("style", "vivid")
            
            logger.info(f"Generating image with prompt: {prompt}")
            
            response = openai_client.images.generate(
                model="dall-e-3",
                prompt=prompt,
                size=size,
                quality=quality,
                style=style,
                response_format="url"
            )
            
            image_url = response.data[0].url
            revised_prompt = response.data[0].revised_prompt
            
            return [
                types.TextContent(
                    type="text",
                    text=f"Generated image successfully!\n\nOriginal prompt: {prompt}\nRevised prompt: {revised_prompt}\nImage URL: {image_url}"
                ),
                types.ImageContent(
                    type="image",
                    data=image_url,
                    mimeType="image/png"
                )
            ]
            
        elif name == "create_variation":
            image_path = arguments.get("image_path")
            if not image_path:
                raise ValueError("image_path is required")
            
            if not os.path.exists(image_path):
                raise ValueError(f"Image file not found: {image_path}")
            
            n = arguments.get("n", 1)
            size = arguments.get("size", "1024x1024")
            
            logger.info(f"Creating {n} variation(s) of image: {image_path}")
            
            with open(image_path, "rb") as image_file:
                response = openai_client.images.create_variation(
                    image=image_file,
                    n=n,
                    size=size,
                    response_format="url"
                )
            
            results = [
                types.TextContent(
                    type="text",
                    text=f"Created {len(response.data)} variation(s) of {image_path}"
                )
            ]
            
            for i, image_data in enumerate(response.data):
                results.append(
                    types.ImageContent(
                        type="image",
                        data=image_data.url,
                        mimeType="image/png"
                    )
                )
            
            return results
            
        else:
            raise ValueError(f"Unknown tool: {name}")
            
    except Exception as e:
        logger.error(f"Error in tool {name}: {str(e)}")
        return [
            types.TextContent(
                type="text",
                text=f"Error: {str(e)}"
            )
        ]

async def main():
    """Main function to run the server."""
    # Import here to avoid issues with event loop
    from mcp.server.stdio import stdio_server
    
    async with stdio_server() as (read_stream, write_stream):
        await server.run(
            read_stream,
            write_stream,
            InitializationOptions(
                server_name="dalle-mcp",
                server_version="0.1.0",
                capabilities=server.get_capabilities(
                    notification_options=NotificationOptions(),
                    experimental_capabilities={},
                ),
            ),
        )

if __name__ == "__main__":
    asyncio.run(main())
