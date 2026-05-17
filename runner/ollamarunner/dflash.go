package ollamarunner

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/ollama/ollama/kvcache"
	"github.com/ollama/ollama/ml"
	"github.com/ollama/ollama/model"
	"github.com/ollama/ollama/model/input"
	"github.com/ollama/ollama/tokenizer"
)

// DFlashTargetModel is an interface that target models must implement
// to support DFlash speculative decoding. It exposes hidden states
// at specified layers during the forward pass.
type DFlashTargetModel interface {
	// ForwardDFlash runs the target model forward pass and captures
	// intermediate hidden states at the specified layer IDs.
	// Returns the final logits tensor and the concatenated hidden states
	// from the requested layers.
	ForwardDFlash(ctx ml.Context, batch input.Batch, layerIDs []int) (logits ml.Tensor, capturedHidden ml.Tensor)

	// ProjectHiddenToLogits projects draft model hidden states to logits
	// using the target model's output projection. The hidden tensor must
	// be on the target model's backend.
	ProjectHiddenToLogits(ctx ml.Context, hidden ml.Tensor) ml.Tensor
}

// DFlashDraftModel is an interface for DFlash block-diffusion draft models.
type DFlashDraftModel interface {
	// ForwardDFlashContext projects captured target hidden states into
	// the draft model's hidden space. This is called before the draft
	// forward pass to initialize the draft model with context from
	// the target model.
	ForwardDFlashContext(ctx ml.Context, targetHidden ml.Tensor) ml.Tensor

	// TargetLayerIDs returns the target model layer IDs to capture
	// hidden states from.
	TargetLayerIDs() []int

	// BlockSize returns the number of draft tokens to generate per
	// speculative decoding iteration.
	BlockSize() int32

	// MaskTokenID returns the mask token ID used for padding in
	// block diffusion.
	MaskTokenID() int32
}

// dflashStats tracks speculative decoding statistics.
type dflashStats struct {
	iterations       int
	drafted          int
	accepted         int
	mismatches       int
	allAccepted      int
	targetDuration   time.Duration
	draftDuration    time.Duration
	validateDuration time.Duration
}

// dflashDecodeMode indicates whether DFlash is active and in which mode.
type dflashDecodeMode int

const (
	dflashDisabled dflashDecodeMode = iota
	dflashGreedy
	dflashSample
)

func (m dflashDecodeMode) enabled() bool {
	return m != dflashDisabled
}

// dflashGate determines whether DFlash speculative decoding should be
// used for the given request.
func (s *Server) dflashGate(temperature float32) (dflashDecodeMode, string) {
	if s.draftModel == nil {
		return dflashDisabled, "no_draft"
	}

	if _, ok := s.draftModel.(DFlashDraftModel); !ok {
		return dflashDisabled, "draft_not_dflash"
	}

	if _, ok := s.model.(DFlashTargetModel); !ok {
		return dflashDisabled, "target_not_dflash"
	}

	if temperature > 0 {
		return dflashSample, ""
	}

	return dflashGreedy, ""
}

// runDFlashDecode executes a DFlash speculative decoding loop for a single
// sequence. This bypasses the normal batch pipeline and runs the target and
// draft models serially.
//
// The loop:
//
//  1. Prefill target model on the prompt tokens
//  2. For each decode step:
//     a. Run target forward → capture hidden states at target_layer_ids
//     b. Project captured states into draft model space
//     c. Generate draft tokens (block_size iterations)
//     d. Verify draft tokens against target (serial verification)
//     e. Emit accepted tokens
func (s *Server) runDFlashDecode(
	ctx context.Context,
	seq *Sequence,
	initialToken int32,
) error {
	target, ok := s.model.(DFlashTargetModel)
	if !ok {
		return fmt.Errorf("dflash: target model does not implement DFlashTargetModel")
	}
	draft, ok := s.draftModel.(DFlashDraftModel)
	if !ok {
		return fmt.Errorf("dflash: draft model does not implement DFlashDraftModel")
	}

	stats := dflashStats{}
	blockSize := draft.BlockSize()
	layerIDs := draft.TargetLayerIDs()
	slog.Info("DFlash decode enabled", "block_size", blockSize, "target_layers", layerIDs)

	tok := s.model.(tokenizer.Tokenizer)
	numPredict := seq.numPredict
	generated := 0

	// Current position tracks where we are in the sequence
	position := int32(len(seq.cache.Inputs))

	// Emit a token to the sequence's response channel
	emitToken := func(token int32) (bool, error) {
		if tok.Is(token, tokenizer.SpecialEOS) {
			return true, nil
		}

		piece, err := tok.Decode([]int32{token})
		if err != nil {
			return false, fmt.Errorf("dflash: failed to decode token: %w", err)
		}

		select {
		case seq.responses <- response{content: piece}:
		case <-seq.quit:
			return false, nil
		case <-ctx.Done():
			return false, ctx.Err()
		}

		return false, nil
	}

	// targetForward runs the target model forward on the given tokens,
	// computes the graph, and returns logits, captured hidden states,
	// and the backend context. The caller MUST close the context after
	// reading logits and after capturedHidden is consumed (e.g. by
	// generateDraftTokens which reads it as a GPU tensor).
	targetForward := func(tokens []int32) (logits ml.Tensor, capturedHidden ml.Tensor, ctx ml.Context) {
		t0 := time.Now()
		ctx = s.model.Backend().NewContext()

		block := input.Batch{
			Inputs:    ctx.Input().FromInts(tokens, len(tokens)),
			Positions: make([]int32, len(tokens)),
			Sequences: make([]int, len(tokens)),
		}
		for i := range tokens {
			block.Positions[i] = position + int32(i)
			block.Sequences[i] = seq.cache.Id
		}

		logits, capturedHidden = target.ForwardDFlash(ctx, block, layerIDs)
		ctx.Forward(logits, capturedHidden)
		ctx.Compute(logits, capturedHidden)
		position += int32(len(tokens))
		stats.targetDuration += time.Since(t0)
		return
	}

	// generateDraftTokens generates draft tokens using the draft model.
	// It projects captured target hidden states into draft space, runs
	// the draft model forward (which returns hidden states, not logits),
	// then projects those hidden states to logits using the target model's
	// output projection.
	generateDraftTokens := func(capturedHidden ml.Tensor, currentToken int32, draftCount int, draftPosition int32) []int32 {
		t0 := time.Now()

		// Build block input: [current_token, mask, mask, ..., mask]
		blockLen := draftCount + 1
		blockTokens := make([]int32, blockLen)
		blockTokens[0] = currentToken
		for i := 1; i < blockLen; i++ {
			blockTokens[i] = draft.MaskTokenID()
		}

		// Create a context on the draft model's backend.
		// IMPORTANT: call Input() FIRST to set buft before any FromFloats
		// or other tensor creation (ggml requires buft for newTensor).
		draftCtx := s.draftModel.Backend().NewContext()
		defer draftCtx.Close()
		draftInputCtx := draftCtx.Input()

		// Copy captured hidden states to draft backend.
		// capturedHidden lives in GPU memory on the target backend, but the
		// draft model runs on CPU. Reading via Floats() forces GPU→CPU copy,
		// then FromFloats creates a new tensor on the draft model's backend.
		hiddenShape := capturedHidden.Shape()
		hiddenFloats := capturedHidden.Floats()
		capturedForDraft := draftInputCtx.FromFloats(hiddenFloats, hiddenShape...)

		// Project target hidden states into draft space and store in
		// the draft model's projectedHidden field for use by Forward.
		draft.ForwardDFlashContext(draftCtx, capturedForDraft)

		// Build the batch for the draft model forward pass.
		block := input.Batch{
			Inputs:    draftCtx.Input().FromInts(blockTokens, blockLen),
			Positions: make([]int32, blockLen),
			Sequences: make([]int, blockLen),
		}
		for i := range blockLen {
			block.Positions[i] = draftPosition + int32(i)
			block.Sequences[i] = 0 // draft uses slot 0
		}

		// Start forward on the draft model's cache
		draftCache := s.draftModel.Config().Cache
		if draftCache != nil {
			if err := draftCache.StartForward(draftCtx, block, false); err != nil {
				slog.Error("dflash: draft cache start forward failed", "error", err)
				stats.draftDuration += time.Since(t0)
				return nil
			}
		}

		// Run draft model forward — returns hidden states because the
		// draft model has no output projection.
		hidden, err := s.draftModel.Forward(draftCtx, block)
		if err != nil {
			slog.Error("dflash: draft forward failed", "error", err)
			stats.draftDuration += time.Since(t0)
			return nil
		}
		draftCtx.Forward(hidden)
		draftCtx.Compute(hidden)

		// Read hidden states from draft backend.
		hiddenFloats = hidden.Floats()
		hiddenShape = hidden.Shape()
		if len(hiddenFloats) == 0 || len(hiddenShape) < 2 {
			slog.Error("dflash: draft forward produced no hidden states")
			stats.draftDuration += time.Since(t0)
			return nil
		}

		// Copy hidden states to target backend and project to logits.
		// CRITICAL: allocate on GPU so ProjectHiddenToLogits can Mulmat
		// with GPU weights without cross-device copy (SIGSEGV).
		targetCtx := s.model.Backend().NewContext()
		gpuCtx := targetCtx.Layer(0)
		targetHidden := gpuCtx.Empty(ml.DTypeF32, hiddenShape...)
		targetHidden.FromFloats(hiddenFloats)
		logits := target.ProjectHiddenToLogits(targetCtx, targetHidden)
		targetCtx.Forward(logits)
		targetCtx.Compute(logits)

		// Extract draft tokens from projected logits.
		outputs := logits.Floats()
		vocabSize := logits.Dim(0)
		if vocabSize == 0 || len(outputs) == 0 {
			targetCtx.Close()
			slog.Error("dflash: draft forward projection produced no logits")
			stats.draftDuration += time.Since(t0)
			return nil
		}
		targetCtx.Close()

		result := make([]int32, draftCount)
		for i := range draftCount {
			offset := (i + 1) * vocabSize
			if offset+vocabSize > len(outputs) {
				break
			}
			result[i] = argmaxToken(outputs[offset:offset+vocabSize], vocabSize)
		}

		stats.draftDuration += time.Since(t0)
		stats.drafted += draftCount
		return result
	}

	// verifyDraftTokens checks draft tokens against the target model
	// in serial mode (one token at a time). Returns the number of
	// accepted tokens and the next token to continue from.
	verifyDraftTokens := func(draftTokens []int32, currentToken int32) (accepted int, nextToken int32, done bool, err error) {
		t0 := time.Now()
		defer func() {
			stats.validateDuration += time.Since(t0)
		}()

		// Run target forward on current token to get its prediction.
		// capturedHidden is not needed here (it's only used for draft generation,
		// not during verification of already-generated draft tokens).
		logits, _, targetCtx := targetForward([]int32{currentToken})
		outputs := logits.Floats()
		targetCtx.Close()
		if len(outputs) == 0 {
			return 0, 0, false, fmt.Errorf("dflash: target forward produced no output")
		}

		vocabSize := len(outputs)
		targetToken := argmaxToken(outputs, vocabSize)

		for _, draftToken := range draftTokens {
			if targetToken != draftToken {
				return accepted, targetToken, false, nil
			}

			accepted++

			if tok.Is(draftToken, tokenizer.SpecialEOS) {
				return accepted, draftToken, true, nil
			}

			stop, err := emitToken(draftToken)
			if err != nil {
				return accepted, draftToken, stop, err
			}
			if stop {
				return accepted, draftToken, true, nil
			}
			generated++
			if generated >= numPredict {
				return accepted, draftToken, true, nil
			}

			// Run target forward on this accepted token to get next prediction
			logits, _, targetCtx = targetForward([]int32{draftToken})
			outputs = logits.Floats()
			targetCtx.Close()
			if len(outputs) == 0 {
				return accepted, draftToken, false, fmt.Errorf("dflash: target forward produced no output")
			}
			targetToken = argmaxToken(outputs, vocabSize)
		}

		// All draft tokens accepted — return the bonus token from target
		return accepted, targetToken, false, nil
	}

	// Main decode loop
	for generated < numPredict {
		if err := ctx.Err(); err != nil {
			return err
		}

		draftCount := int(blockSize) - 1
		remaining := numPredict - generated
		if draftCount > remaining {
			draftCount = remaining
		}
		if draftCount <= 0 {
			// No room for drafting, just do a regular decode step.
			// capturedHidden is discarded since there's no draft to generate.
			logits, _, targetCtx := targetForward([]int32{0})
			outputs := logits.Floats()
			targetCtx.Close()
			if len(outputs) == 0 {
				return fmt.Errorf("dflash: target forward produced no output")
			}
			token := argmaxToken(outputs, len(outputs))

			if tok.Is(token, tokenizer.SpecialEOS) {
				return nil
			}
			stop, err := emitToken(token)
			if err != nil {
				return err
			}
			if stop {
				return nil
			}
			generated++
			continue
		}

		stats.iterations++

		// Run target forward on the current token to get logits
		// and captured hidden states for draft model context.
		// The context MUST stay alive until generateDraftTokens returns
		// because capturedHidden is a GPU tensor used as input there.
		logits, capturedHidden, targetCtx := targetForward([]int32{0})
		outputs := logits.Floats()
		if len(outputs) == 0 {
			targetCtx.Close()
			return fmt.Errorf("dflash: target forward produced no output")
		}
		currentToken := argmaxToken(outputs, len(outputs))

		if tok.Is(currentToken, tokenizer.SpecialEOS) {
			targetCtx.Close()
			return nil
		}

		// Generate draft tokens using the draft model.
		// capturedHidden is consumed by generateDraftTokens, which copies
		// the data from GPU to CPU or processes it within its own context.
		draftTokens := generateDraftTokens(capturedHidden, currentToken, draftCount, position)
		// Close the target context now that capturedHidden is no longer needed
		targetCtx.Close()

		if len(draftTokens) > 0 {
			accepted, nextToken, done, err := verifyDraftTokens(draftTokens, currentToken)
			if err != nil {
				return err
			}
			if done {
				return nil
			}

			// Emit the initial target token (it was accepted by definition)
			stop, err := emitToken(currentToken)
			if err != nil {
				return err
			}
			if stop {
				return nil
			}
			generated++

			stats.accepted += accepted
			if accepted == draftCount {
				stats.allAccepted++
			} else {
				stats.mismatches++
			}

			// Emit the bonus/next token from verification
			if !tok.Is(nextToken, tokenizer.SpecialEOS) && generated < numPredict {
				stop, err = emitToken(nextToken)
				if err != nil {
					return err
				}
				if stop {
					return nil
				}
				generated++
			}
		} else {
			// No draft tokens generated - emit the target token directly
			stop, err := emitToken(currentToken)
			if err != nil {
				return err
			}
			if stop {
				return nil
			}
			generated++
		}
	}

	// Log final stats
	acceptance := 0.0
	if stats.drafted > 0 {
		acceptance = float64(stats.accepted) / float64(stats.drafted)
	}
	slog.Info("DFlash decode stats",
		"generated", generated,
		"drafted", stats.drafted,
		"accepted", stats.accepted,
		"acceptance", acceptance,
		"iterations", stats.iterations,
		"mismatches", stats.mismatches,
		"all_accepted", stats.allAccepted,
		"block_size", blockSize,
		"target_layers", layerIDs,
		"target_duration", stats.targetDuration,
		"draft_duration", stats.draftDuration,
		"validate_duration", stats.validateDuration,
	)

	return nil
}

// argmaxToken returns the token ID with the highest logit value.
func argmaxToken(logits []float32, vocabSize int) int32 {
	if len(logits) == 0 || vocabSize == 0 {
		return 0
	}

	bestIdx := 0
	bestVal := logits[0]
	for i := 1; i < vocabSize && i < len(logits); i++ {
		if logits[i] > bestVal {
			bestVal = logits[i]
			bestIdx = i
		}
	}
	return int32(bestIdx)
}

// loadDraftModel loads a DFlash draft model from the given GGUF path.
// It creates a separate model instance and verifies the architecture,
// but does NOT load weights into memory — that happens in loadDraftWeights
// after the target model's weights are loaded, to avoid CUDA state conflicts
// from multiple backends loading in the same process.
func (s *Server) loadDraftModel(path string, params ml.BackendParams) error {
	slog.Info("loading draft model (metadata only)", "path", path)

	// Use CPU-only params for the draft model — it's small and the target
	// model's GPU layer allocation (e.g. 65 layers across 2 GPUs) doesn't
	// apply to the draft model's different architecture.
	draftParams := params
	draftParams.GPULayers = nil

	draftModel, err := model.New(path, draftParams)
	if err != nil {
		return fmt.Errorf("dflash: failed to create draft model: %w", err)
	}

	// Verify the draft model implements DFlashDraftModel
	draft, ok := draftModel.(DFlashDraftModel)
	if !ok {
		draftModel.Backend().Close()
		return fmt.Errorf("dflash: draft model architecture %q does not implement DFlashDraftModel", draftModel.Config().Cache)
	}

	s.draftModel = draftModel
	slog.Info("draft model metadata loaded",
		"path", path,
		"block_size", draft.BlockSize(),
		"target_layers", draft.TargetLayerIDs(),
		"mask_token_id", draft.MaskTokenID(),
	)
	return nil
}

// loadDraftWeights loads the draft model weights and creates its cache.
// Must be called BEFORE the target model weights are loaded so that the
// target model's scheduler is created last with a clean CUDA state.
// The ggml CUDA backend shares process-global device handles, so loading
// weights after the target model has built its scheduler corrupts the
// target's GPU scratch buffers (SIGSEGV in computeBatch).
func (s *Server) loadDraftWeights() error {
	if s.draftModel == nil || s.draftCache != nil {
		return nil // already loaded or no draft model
	}

	slog.Info("loading draft model weights")
	if err := s.draftModel.Backend().Load(context.TODO(), func(progress float32) {
		slog.Info("loading draft model weights", "progress", progress)
	}); err != nil {
		s.draftModel.Backend().Close()
		s.draftModel = nil
		return fmt.Errorf("dflash: failed to load draft model weights: %w", err)
	}

	if postLoader, ok := s.draftModel.(model.PostLoader); ok {
		if err := postLoader.PostLoad(); err != nil {
			s.draftModel.Backend().Close()
			s.draftModel = nil
			return fmt.Errorf("dflash: draft model post-load failed: %w", err)
		}
	}

	cache, err := NewInputCache(s.draftModel, "f16", int32(s.cache.numCtx), 1, s.batchSize, false)
	if err != nil {
		s.draftModel.Backend().Close()
		s.draftModel = nil
		return fmt.Errorf("dflash: failed to create draft cache: %w", err)
	}
	s.draftCache = cache

	slog.Info("draft model weights loaded")
	return nil
}

// closeDraftModel frees all memory associated with the draft model.
func (s *Server) closeDraftModel() {
	if s.draftCache != nil {
		s.draftCache.Close()
		s.draftCache = nil
	}
	if s.draftModel != nil {
		s.draftModel.Backend().Close()
		s.draftModel = nil
	}
}

// newDraftCache creates a KV cache for the draft model.
func newDraftCache(draft DFlashDraftModel, backend ml.Backend, kvSize int32) kvcache.Cache {
	// This is now handled by NewInputCache in loadDraftModel().
	// Kept for interface compatibility.
	return nil
}
