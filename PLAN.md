# Implementation Plan: DFlash/PFlash/Megakernel Integration into Ollama

## Requirements Restatement

Integrate the Lucebox project's DFlash (block-diffusion speculative decoding), PFlash (speculative prefill), and Megakernel (fused CUDA decode) into the Ollama GGUF/CUDA backend path. This means:

1. **Go Layer**: Add `--draft-model` flag (runtime), `--use-dflash`, `--use-pflash`, `--use-megakernel` flags, and wire them from CLI → API → server → runner
2. **C++ Backend**: Integrate the luce-dflash llama.cpp fork (3 custom ggml ops) and the dflash27b C++ library into the Ollama build
3. **Runner Integration**: Add DFlash speculative decode loop to `ollamarunner` (paralleling the existing MLX DFlash implementation)
4. **Build & Test**: All compilation/testing on AISERVER (Linux, CUDA)
5. **Preserve MLX**: Do NOT break the existing Apple MLX backend

## Key Architectural Insight

**Ollama has two engine paths:**
- **Legacy (llamarunner)**: Uses llama.cpp's libllama via cgo + subprocess. Model graph built in C++. No speculative decoding.
- **New (ollamarunner)**: Go-native model graph execution via `ml` package + ggml tensor ops. Already has draft model infrastructure (MTP, DFlash) in the **MLX** runner but NOT in the ggml/CUDA runner.

**The DFlash C++ library (dflash27b) is a standalone inference engine** that only uses ggml (not libllama). It builds its own target+draft graphs using ggml tensor ops — essentially the same approach as ollamarunner but in C++.

### Integration Strategy Decision

Two possible approaches:

**Option A: Extend ollamarunner (Go-native path)** — Implement DFlash speculative decoding in Go, similar to how `x/mlxrunner/dflash.go` does it for MLX. This means:
- Adding DFlash draft model support to `model/models/qwen3_5/` (Go model definitions)
- Adding DFlash decode loop to `runner/ollamarunner/`
- Requires the 3 custom ggml ops from the luce-dflash fork for DDTree verify
- DFlash draft model Go code already exists at `x/models/dflash/dflash.go` (MLX-specific, needs porting)

**Option B: Daemon/subprocess model (like the original dflash27b)** — Run dflash27b as a separate subprocess, similar to how the original lucebox daemon works. This means:
- Minimal Go changes (just spawn the dflash daemon instead of the regular runner)
- All C++ logic stays in the dflash27b library
- Simpler but loses Ollama's memory management, scheduling, and model switching

**RECOMMENDATION: Option A (Extend ollamarunner)** — This is the correct long-term approach because:
1. Ollama's memory scheduler, model loading, and parallel request handling work with ollamarunner
2. The DFlash MLX implementation already proves the pattern works
3. The 3 custom ggml ops just need to be ported into Ollama's ggml tree
4. DFlash draft model architecture is simple (5 layers, ~439 lines of Go for MLX)

However, Option A requires significant work. **We will implement a hybrid:**
- Phase 1: Go layer changes (flags, API, server wiring) — immediate
- Phase 2: Custom ggml ops port (3 ops from luce-dflash fork) — required for DDTree
- Phase 3: DFlash draft model in Go (port from MLX) + decode loop in ollamarunner
- Phase 4: PFlash and Megakernel as optional engine modes

---

## Phase 1: Go Layer Changes (Priority)

### 1.1 API Types — `api/types.go`

Add draft model and engine options to the `Runner` struct:

```go
type Runner struct {
    NumCtx      int    `json:"num_ctx,omitempty"`
    NumBatch    int    `json:"num_batch,omitempty"`
    NumGPU      int    `json:"num_gpu,omitempty"`
    MainGPU     int    `json:"main_gpu,omitempty"`
    UseMMap     *bool  `json:"use_mmap,omitempty"`
    NumThread   int    `json:"num_thread,omitempty"`
    // NEW: Speculative decoding options
    DraftModel  string `json:"draft_model,omitempty"`   // path to draft GGUF
    UseDFlash   bool   `json:"use_dflash,omitempty"`    // enable DFlash spec-decode
    UsePFlash   bool   `json:"use_pflash,omitempty"`    // enable PFlash spec-prefill
    UseMegakernel bool `json:"use_megakernel,omitempty"` // enable megakernel decode
}
```

### 1.2 CLI Flags — `cmd/cmd.go`

Add flags to the `run` command:

```go
// In the run command flag setup:
runCmd.Flags().String("draft-model", "", "Path to draft model GGUF for speculative decoding")
runCmd.Flags().Bool("use-dflash", false, "Enable DFlash block-diffusion speculative decoding")
runCmd.Flags().Bool("use-pflash", false, "Enable PFlash speculative prefill")
runCmd.Flags().Bool("use-megakernel", false, "Enable fused megakernel CUDA decode")
```

Wire these into the `Options` map sent to the API:

```go
// In the run handler, after parsing flags:
if draftModel, _ := cmd.Flags().GetString("draft-model"); draftModel != "" {
    opts["draft_model"] = draftModel
}
if useDFlash, _ := cmd.Flags().GetBool("use-dflash"); useDFlash {
    opts["use_dflash"] = true
}
// Similarly for use-pflash and use-megakernel
```

### 1.3 Server Layer — `server/sched.go`

Modify the `load()` function to pass draft model path to the runner:

```go
// In load(), after creating the server (line ~444):
// Pass draft model options to the runner via LoadRequest
if req.opts.DraftModel != "" {
    // Validate draft model exists
    if _, err := os.Stat(req.opts.DraftModel); err != nil {
        slog.Error("draft model not found", "path", req.opts.DraftModel, "error", err)
        req.errCh <- fmt.Errorf("draft model not found: %s", req.opts.DraftModel)
        s.loadedMu.Unlock()
        return false
    }
}
```

### 1.4 LLM Layer — `llm/server.go`

Add draft model fields to `LoadRequest`:

```go
type LoadRequest struct {
    Operation     LoadOperation
    LoraPath      []string
    Parallel      int
    BatchSize     int
    FlashAttention ml.FlashAttentionType
    KvSize        int
    KvCacheType   string
    NumThreads    int
    GPULayers     ml.GPULayersList
    MultiUserCache bool
    // NEW: DFlash/PFlash/Megakernel options
    DraftModel    string `json:"draft_model,omitempty"`
    UseDFlash     bool   `json:"use_dflash,omitempty"`
    UsePFlash     bool   `json:"use_pflash,omitempty"`
    UseMegakernel bool   `json:"use_megakernel,omitempty"`
    // Legacy fields
    ProjectorPath string
    MainGPU       int
    UseMmap       bool
}
```

### 1.5 Runner Layer — `runner/ollamarunner/runner.go`

Modify the `load()` handler to accept draft model path and pass it to the model allocation:

```go
// In load(), after parsing LoadRequest:
if req.DraftModel != "" {
    s.draftModelPath = req.DraftModel
    s.useDFlash = req.UseDFlash
    s.usePFlash = req.UsePFlash
    s.useMegakernel = req.UseMegakernel
}
```

Add draft model loading in the model loading path:

```go
// After the target model is loaded, if a draft model is specified:
if s.draftModelPath != "" && s.useDFlash {
    draft, err := dflash.LoadDraft(s.draftModelPath, s.model)
    if err != nil {
        slog.Error("failed to load draft model", "path", s.draftModelPath, "error", err)
        // Continue without draft model (graceful degradation)
    } else {
        s.draft = draft
        slog.Info("loaded DFlash draft model", "path", s.draftModelPath)
    }
}
```

---

## Phase 2: Custom ggml Ops Port

The luce-dflash llama.cpp fork adds 3 custom ggml ops needed for DDTree verify mode:

1. **`ggml_ssm_conv_tree`** — Tree-aware conv state gather (for DeltaNet layers)
2. **`ggml_gated_delta_net_tree`** — Tree-mode DeltaNet verify
3. **`ggml_gated_delta_net_tree_persist`** — Persistent SSM intermediate buffer

### 2.1 Source Files to Port

From `dflash/deps/llama.cpp/ggml/src/ggml-cuda/`:
- `ssm-conv-tree.cu` (new kernel)
- `gated-delta-net-tree.cu` (new kernel)
- `gated-delta-net-tree-persist.cu` (new kernel)

From `dflash/deps/llama.cpp/ggml/src/ggml-cpu/`:
- `ops-ssm-conv-tree.cpp` (new op)
- `ops-gated-delta-net-tree.cpp` (new op)

From `dflash/deps/llama.cpp/ggml/include/`:
- Updated `ggml.h` with op type enums and function declarations

### 2.2 Integration Approach

1. **Copy the CUDA kernels** into `ml/backend/ggml/ggml/src/ggml-cuda/`
2. **Copy the CPU fallback ops** into `ml/backend/ggml/ggml/src/ggml-cpu/`
3. **Add op type enums** to `ml/backend/ggml/ggml/include/ggml.h`
4. **Register the ops** in the ggml backend dispatch tables
5. **Update CMakeLists.txt** to include the new source files

### 2.3 GGUF Format Extension

The DFlash draft model uses a custom GGUF format with:
- `dflash_config.target_layer_ids` — which target layers to capture
- `dflash_config.mask_token_id` — the mask token ID
- Standard Qwen3 architecture fields for the draft layers
- Draft model tensors prefixed with `draft.`

This is already handled by the GGUF reader in `fs/ggml/ggml.go` since it reads arbitrary KV pairs.

---

## Phase 3: DFlash Draft Model in Go (ollamarunner)

### 3.1 Model Definition — `model/models/dflash/`

Port the DFlash draft model from `x/models/dflash/dflash.go` (MLX) to use the `ml` package (ggml):

```go
package dflash

import (
    "github.com/ollama/ollama/ml"
    "github.com/ollama/ollama/ml/nn"
    "github.com/ollama/ollama/model"
    "github.com/ollama/ollama/model/input"
)

// Model implements a DFlash block-diffusion draft model for speculative decoding.
type Model struct {
    BaseModelConfig
    FC       nn.Linear `nn:"fc"`          // Projection: target_hidden → draft_hidden
    Norm     nn.RMSNorm `nn:"norm"`       // Hidden norm
    Layers   []Layer    `nn:"layers"`     // 5 draft layers
    LMHead   nn.Linear  `nn:"lm_head"`   // Logits
    // Config
    TargetLayerIDs []int
    MaskTokenID    int32
    BlockSize      int32
}

type Layer struct {
    SelfAttention nn.Linear `nn:"self_attn"`
    MLP          nn.Linear `nn:"mlp"`
    // ...
}

func (m *Model) Forward(ctx ml.Context, hidden ml.Tensor, caches []ml.Cache) ml.Tensor {
    // Project target hidden states into draft space
    hidden = m.FC.Forward(ctx, hidden)
    hidden = m.Norm.Forward(ctx, hidden)
    // Run through draft layers
    for i, layer := range m.Layers {
        hidden = layer.Forward(ctx, hidden, caches[i])
    }
    // Produce logits
    return m.LMHead.Forward(ctx, hidden)
}
```

### 3.2 Decode Loop — `runner/ollamarunner/dflash.go`

Port the decode loop from `x/mlxrunner/dflash.go`:

```go
package ollamarunner

// runDFlashDecode implements the DFlash speculative decode loop:
// 1. Prefill target model → capture hidden states at target_layer_ids
// 2. Project captured states into draft model
// 3. Draft forward → generate N draft tokens
// 4. Target verify (DDTree mode) → accept/reject draft tokens
// 5. Emit accepted tokens

func (s *Server) runDFlashDecode(ctx ml.Context, input input.Input, tokens []int, opts sample.Options) ([]int, error) {
    // Step 1: Target forward with layer capture
    targetHidden, capturedHidden := s.model.ForwardDFlash(ctx, input, s.targetCaches, s.draft.TargetLayerIDs)

    // Step 2: Draft context from captured states
    draftInput := s.draft.ProjectContext(ctx, capturedHidden)

    // Step 3: Generate draft tokens (block_size iterations)
    draftTokens := make([]int, 0, s.draft.BlockSize)
    for i := 0; i < int(s.draft.BlockSize); i++ {
        logits := s.draft.Forward(ctx, draftInput, s.draftCaches)
        token := sample.Argmax(logits)
        draftTokens = append(draftTokens, token)
        draftInput = s.draft.TokenEmbedding(ctx, token)
    }

    // Step 4: Target verify (batch forward on all draft tokens)
    accepted := s.verifyDraft(ctx, draftTokens, input)

    // Step 5: Emit accepted tokens + bonus token
    return accepted, nil
}
```

### 3.3 Qwen3.5 Target Model — `x/models/qwen3_5/qwen3_5.go`

The MLX version already has `ForwardDFlash()` and `TokenEmbeddings()`. For the ggml/ollamarunner path, these need to be added to the Go model definitions in `model/models/`:

```go
// In model/models/qwen3next/ or a new qwen35 package:
func (m *Model) ForwardDFlash(ctx ml.Context, tokens []int, caches []ml.Cache, layerIDs []int) (ml.Tensor, ml.Tensor) {
    // Run target forward, capturing hidden states at specified layer IDs
    // Return: final hidden state, concatenated intermediate hidden states
}
```

---

## Phase 4: PFlash and Megakernel (Optional/Later)

### 4.1 PFlash (Speculative Prefill)

PFlash adds a 4-kernel FlashPrefill pipeline that compresses long prefill sequences:
- Uses a small drafter model (Qwen3-0.6B) to score token importance
- Compresses KV cache by keeping important tokens and discarding others
- Reduces prefill time for long contexts

**Integration approach:** Add as a prefill optimization flag in the runner. When enabled, the prefill path uses the flashprefill kernels instead of standard attention.

**C++ code needed:**
- `dflash/src/flashprefill.cpp` + `flashprefill_kernels.cu` + `flashprefill_select.cpp`
- `dflash/src/qwen3_drafter.h/cpp` + `qwen3_0p6b_drafter.h/cpp`
- Block-Sparse-Attention kernels (`bsa_fwd_inst.cu`, `bsa_launcher.cu`)

### 4.2 Megakernel

Megakernel fuses all 24 layers of a small model (0.8B) into a single CUDA dispatch, reducing kernel launch overhead:
- Standalone CUDA kernels (no ggml dependency)
- Currently targets Qwen3.5-0.8B only
- Requires PyTorch for weight loading (not GGUF-compatible)

**Integration approach:** This is the lowest priority because:
1. It targets a different model size (0.8B vs 27B)
2. It requires PyTorch for weight loading (not GGUF)
3. It's not directly usable in the Ollama/ggml path

For now, we add the `--use-megakernel` flag as a placeholder and document the future integration path.

---

## Phase 5: Build & Test on AISERVER

### 5.1 AISERVER Environment

```
Server: AISERVER
User: cesar
Password: s0NYps02
Ollama source: ~/ollama
Network share: \\192.168.200.15\ollamallm
```

### 5.2 Build Commands on AISERVER

```bash
# 1. SSH into AISERVER
ssh cesar@AISERVER

# 2. Navigate to ollama source
cd ~/ollama

# 3. Copy dflash library files from network share
# (First copy from Windows to the share, then from share to AISERVER)
mkdir -p ml/backend/ggml/dflash/src
mkdir -p ml/backend/ggml/dflash/include
cp -r /mnt/share/dflash/src/* ml/backend/ggml/dflash/src/
cp -r /mnt/share/dflash/include/* ml/backend/ggml/dflash/include/

# 4. Build Ollama with DFlash support
# The go:generate command builds the C++ layer
go generate ./...

# 5. Build the Go binary
go build -o ollama .

# 6. Verify the binary
./ollama --version
```

### 5.3 CMake Integration

Add to `CMakeLists.txt`:

```cmake
# DFlash backend (optional, CUDA only)
option(DFLASH_BACKEND "Enable DFlash speculative decoding backend" OFF)
if(DFLASH_BACKEND AND CMAKE_CUDA_COMPILER)
    add_subdirectory(ml/backend/ggml/dflash)
    target_include_directories(dflash27b PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/ml/backend/ggml/dflash/include
        ${CMAKE_CURRENT_SOURCE_DIR}/ml/backend/ggml/ggml/include
    )
    install(TARGETS dflash27b
        RUNTIME DESTINATION ${OLLAMA_INSTALL_DIR} COMPONENT DFLASH
        LIBRARY DESTINATION ${OLLAMA_INSTALL_DIR} COMPONENT DFLASH
    )
endif()
```

### 5.4 Model Preparation on AISERVER

```bash
# Create GGUF directory
mkdir -p ~/ollama/GGUF

# Copy model files from network share
# The target model (Qwen3.6 27B) should be a standard GGUF file
# The draft model should be a DFlash GGUF file

# If converting from the original format:
cd ~/ollama
python3 ml/backend/ggml/dflash/scripts/convert_dflash_to_gguf.py \
    --input /path/to/draft-safetensors/ \
    --output GGUF/dflash-draft-3.6-q8_0.gguf
```

### 5.5 Test Commands on AISERVER

```bash
# Test 1: Basic run without DFlash (regression test)
./ollama run qwen3.6:27b "Hello, world!"

# Test 2: Run with DFlash speculative decoding
./ollama run qwen3.6:27b --draft-model ~/ollama/GGUF/dflash-draft-3.6-q8_0.gguf "Hello, world!"

# Test 3: Run with DFlash and explicit flag
./ollama run qwen3.6:27b --draft-model ~/ollama/GGUF/dflash-draft-3.6-q8_0.gguf --use-dflash "Explain quantum computing"

# Test 4: Verify DFlash is actually being used
# Check logs for "loaded DFlash draft model" message
OLLAMA_DEBUG=1 ./ollama run qwen3.6:27b --draft-model ~/ollama/GGUF/dflash-draft-3.6-q8_0.gguf "Hello" 2>&1 | grep -i dflash
```

---

## Implementation Order & Estimates

| Phase | Description | Complexity | Dependencies |
|-------|-------------|------------|--------------|
| 1.1 | API types (Runner struct) | Low | None |
| 1.2 | CLI flags | Low | None |
| 1.3 | Server wiring | Medium | 1.1, 1.2 |
| 1.4 | LoadRequest extension | Low | 1.1 |
| 1.5 | Runner draft loading | Medium | 1.4, 3.1 |
| 2.1 | Custom ggml ops (CUDA) | High | None (can start in parallel) |
| 2.2 | Custom ggml ops (CPU) | Medium | 2.1 |
| 2.3 | GGUF format support | Low | Already works |
| 3.1 | DFlash draft model (Go) | High | 2.1 (for DDTree) |
| 3.2 | DFlash decode loop | High | 3.1, 1.5 |
| 3.3 | Qwen3.5 target DFlash | Medium | 3.1 |
| 5.1-5.5 | Build & test on AISERVER | Medium | All above |

---

## Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| Custom ggml ops break existing CUDA kernels | HIGH | Port ops incrementally, test each op independently |
| DFlash draft model tensor format mismatch | HIGH | Use existing GGUF converter from lucebox scripts |
| DDTree verify requires exact numerical match with target | HIGH | Start with chain-mode verify (already in upstream ggml), add DDTree later |
| Memory pressure from dual-model loading | MEDIUM | Ollama's memory scheduler already handles this; add draft model VRAM estimation |
| PFlash BSA kernels require sm_80+ | MEDIUM | Add runtime GPU capability check, graceful fallback |
| Megakernel not GGUF-compatible | LOW | Mark as experimental, future work |
| Build complexity on AISERVER | MEDIUM | Provide exact step-by-step commands with error checking |

---

## Critical Decision Points

1. **DDTree vs Chain-mode first?** — Chain-mode speculative decode (already supported by upstream ggml `ggml_gated_delta_net`) should be implemented first. DDTree (tree-mode verify) requires the 3 custom ops and is more complex but provides better acceptance rates.

2. **ollamarunner vs llamarunner?** — DFlash should go in ollamarunner (new engine) because it uses Go model definitions and ml.Tensor operations. The llamarunner path uses libllama C++ which would require deeper C++ integration.

3. **Draft model as GGUF or embedded?** — Draft model should be a separate GGUF file specified via `--draft-model`. This is cleaner than embedding the draft in the target model (which is how MLX does it via manifest layers).

---

## Files to Create/Modify

### New Files
- `model/models/dflash/dflash.go` — DFlash draft model definition (ggml)
- `runner/ollamarunner/dflash.go` — DFlash decode loop for ollamarunner
- `ml/backend/ggml/dflash/` — C++ dflash27b library (copied from lucebox)
- `ml/backend/ggml/ggml/src/ggml-cuda/ssm-conv-tree.cu` — Custom op CUDA kernel
- `ml/backend/ggml/ggml/src/ggml-cuda/gated-delta-net-tree.cu` — Custom op CUDA kernel
- `ml/backend/ggml/ggml/src/ggml-cuda/gated-delta-net-tree-persist.cu` — Custom op CUDA kernel

### Modified Files
- `api/types.go` — Add DraftModel, UseDFlash, UsePFlash, UseMegakernel to Runner
- `cmd/cmd.go` — Add CLI flags for draft-model, use-dflash, use-pflash, use-megakernel
- `server/sched.go` — Pass draft model options to runner
- `llm/server.go` — Add draft fields to LoadRequest
- `runner/ollamarunner/runner.go` — Add draft model loading and DFlash dispatch
- `CMakeLists.txt` — Add dflash subdirectory and custom ggml ops
- `ml/backend/ggml/ggml/include/ggml.h` — Add custom op type enums
