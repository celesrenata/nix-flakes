# OpenAI DALL-E MCP Server

This MCP server provides image generation capabilities using OpenAI's DALL-E API, configured for NixOS environments following the standardized MCP setup pattern.

## Features

- Generate images from text descriptions using DALL-E 3
- Create variations of existing images
- Support for different image sizes and quality settings
- Proper error handling and logging
- NixOS-optimized environment with isolated dependencies

## Setup

### 1. Set your OpenAI API key
```bash
export OPENAI_API_KEY=your_api_key_here
```

### 2. Enter the Nix environment
```bash
cd /home/celes/ai/mcp/openai-dalle
nix-shell
```

The environment will automatically:
- Create a Python virtual environment
- Install all required dependencies
- Verify the OpenAI API key is set
- Prepare the MCP server for connections

### 3. Test the setup (optional)
```bash
python test-server.py
```

## Usage

The server provides the following tools:

### generate_image
Generate an image from a text description using DALL-E 3.

Parameters:
- `prompt` (required): Text description of the image to generate
- `size` (optional): Image size - "256x256", "512x512", or "1024x1024" (default)
- `quality` (optional): "standard" (default) or "hd"
- `style` (optional): "vivid" (default) or "natural"

Example:
```
Generate an image of a serene mountain landscape at sunset with a lake reflection
```

### create_variation
Create variations of an existing image.

Parameters:
- `image_path` (required): Path to the source image file
- `n` (optional): Number of variations to generate (1-10, default 1)
- `size` (optional): Image size - "256x256", "512x512", or "1024x1024" (default)

Example:
```
Create 3 variations of /path/to/image.png
```

## Configuration with Amazon Q CLI

To use this MCP server with Amazon Q CLI:

```bash
q configure add-mcp-server openai-dalle /home/celes/ai/mcp/openai-dalle/start-server.sh
```

The server will then be available as `openai-dalle___generate_image` and `openai-dalle___create_variation` tools.

## Files Structure

```
openai-dalle/
├── shell.nix              # Nix environment configuration
├── requirements.txt       # Python dependencies
├── server.py             # Main MCP server implementation
├── start-server.sh       # Server startup script
├── test-server.py        # Test script for verification
├── README.md            # This documentation
└── venv/                # Python virtual environment (auto-created)
```

## Requirements

- OpenAI API key with DALL-E access
- NixOS environment
- Python 3.12+
- Internet connection for API calls

## Troubleshooting

### Server waiting for connections
This is normal behavior - the MCP server uses stdio for communication and waits for input from the MCP client (Amazon Q CLI).

### API Key Issues
- Ensure `OPENAI_API_KEY` is set in your environment
- Verify your OpenAI account has DALL-E API access
- Check your API usage limits

### Dependency Issues
- Run `nix-shell` to ensure all dependencies are installed
- The virtual environment is automatically managed

### Testing
Run the test script to verify everything is working:
```bash
cd /home/celes/ai/mcp/openai-dalle
nix-shell --run "python test-server.py"
```
