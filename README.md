# home-inference-rig

An open-source, portable multi-modal AI inference gateway and hardware-accelerated video rendering rig for **Ubuntu (NVIDIA CUDA)** and **macOS (Apple Silicon / Metal)**.

It combines local LLM, vision, image generation, text-to-speech, and programmatic video rendering behind a single, VRAM-aware orchestration layer—designed to run cleanly on a home GPU workstation or Apple Silicon machine and expose services safely over your preferred remote transport.

## What to Expect in the Final Project

- **Unified AI Inference Gateway (`llama-swap`):** A single OpenAI-compatible API endpoint (`127.0.0.1:8080`) that automatically loads, unloads, and swaps models on demand across:
  - **Text & Vision LLMs** via `llama.cpp` (`llama-server`)
  - **Image Generation** via `stable-diffusion.cpp` (`sd-server`)
  - **Text-to-Speech (TTS)** via `Qwen3-TTS` (CUDA container on Linux, `uv` venv on macOS)
- **Hardware-Accelerated Video Rendering (`remotion/`):** A local Fastify render worker (`127.0.0.1:3001`) that turns structured storyboards, generated images, and synthesized voiceovers into rendered `.mp4` videos using Remotion and `ffmpeg`.
- **MCP Server & CLI (`mcp-server/`):** A local `stdio` Model Context Protocol server (`server-mcp`) and CLI (`server-render`) so coding agents and editors can trigger multi-modal generation and video renders directly.
- **Portable Setup & Verification (`scripts/` & `configs/`):** Idempotent installers, health/smoke-test checks, service templates (`systemd --user` / `launchd`), and client config templates.
- **Loopback-First Security:** All inference and render services bind strictly to `127.0.0.1` with API key authentication, delegating remote access to your chosen ingress layer (SSH tunnel, Caddy/Nginx reverse proxy, or Tailscale).

## License

Licensed under the [Apache License, Version 2.0](LICENSE).
