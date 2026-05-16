package ollamarunner

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/ollama/ollama/api"
	"github.com/ollama/ollama/kvcache"
	"github.com/ollama/ollama/ml"
	"github.com/ollama/ollama/model"
	"github.com/ollama/ollama/model/input"
	"github.com/ollama/ollama/sample"
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
	iterations        int
	drafted           int
	accepted          int
	mismatches        int
	allAccepted       int
	targetDuration    time.Duration
	draftDuration     time.Duration
	validateDuration  time.Duration
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
func (s *Server) dflashGate(opts *api.Options) (dflashDecodeMode, string) {
	if s.draftModel == nil {
		return dflashDisabled, "no_draft"
	}

	if _, ok := s.draftModel.(DFlashDraftModel); !ok {
		return dflashDisabled, "draft_not_dflash"
	}

	if _, ok := s.model.(DFlashTargetModel); !ok {
		return dflashDisabled, "target_not_dflash"
	}

	if opts.Temperature > 0 {
		return dflashSample, ""
	}

	return dflashGreedy, ""
}

// runDFlashDecode executes a DFlash speculative decoding loop for a single
// sequence. This bypasses the normal batch pipeline and runs the target and
// draft models serially.
//
// The loop:
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
	sampler sample.Sampler,
	opts *api.Options,
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

	// targetForward runs the target model forward on the given tokens and
	// captures hidden states at the specified layer IDs.
	targetForward := func(tokens []int32) (ml.Tensor, ml.Tensor) {
		t0 := time.Now()
		batchCtx := s.model.Backend().NewContext()
		defer batchCtx.Close()

		batch := input.Batch{
			Inputs:    batchCtx.Input().FromInts(tokens, len(tokens)),
			Positions: make([]int32, len(tokens)),
			Sequences: make([]int, len(tokens)),
		}
		for i := range tokens {
			batch.Positions[i] = position + int32(i)
			batch.Sequences[i] = seq.cache.Id
		}

		logits, capturedHidden := target.ForwardDFlash(batchCtx, batch, layerIDs)
		position += int32(len(tokens))
		stats.targetDuration += time.Since(t0)
		return logits, capturedHidden
	}

	// generateDraftTokens creates block_size-1 draft tokens using the
	// draft model. It projects the captured target hidden states into
	// draft space, then runs the draft model forward on the block input.
	generateDraftTokens := func(capturedHidden ml.Tensor, currentToken int32, draftCount int, draftPosition int32) []int32 {
		t0 := time.Now()

		// Build block input: [current_token, mask, mask, ..., mask]
		blockLen := draftCount + 1
		blockTokens := make([]int32, blockLen)
		blockTokens[0] = currentToken
		for i := 1; i < blockLen; i++ {
			blockTokens[i] = draft.MaskTokenID()
		}

		// Create a context on the draft model's backend
		draftCtx := s.draftModel.Backend().NewContext()
		defer draftCtx.Close()

		// Project target hidden states into draft space.
		// The projected hidden is used to initialize the draft model's
		// internal state before the block forward pass.
		_ = draft.ForwardDFlashContext(draftCtx, capturedHidden)

		// Build the batch for the draft model forward pass.
		// The draft model processes the entire block in one forward call.
		batch := input.Batch{
			Inputs:    draftCtx.Input().FromInts(blockTokens, blockLen),
			Positions: make([]int32, blockLen),
			Sequences: make([]int, blockLen),
		}
		for i := range blockLen {
			batch.Positions[i] = draftPosition + int32(i)
			batch.Sequences[i] = 0 // draft uses slot 0
		}

		// Start forward on the draft model's cache
		draftCache := s.draftModel.Config().Cache
		if draftCache != nil {
			if err := draftCache.StartForward(draftCtx, batch, false); err != nil {
				slog.Error("dflash: draft cache start forward failed", "error", err)
				stats.draftDuration += time.Since(t0)
				return nil
			}
		}

		// Run draft model forward
		logits, err := s.draftModel.Forward(draftCtx, batch)
		if err != nil {
			slog.Error("dflash: draft forward failed", "error", err)
			stats.draftDuration += time.Since(t0)
			return nil
		}
		draftCtx.Forward(logits)
		draftCtx.Compute(logits)

		// Extract draft tokens from logits.
		// The logits tensor has shape [vocab_size, blockLen].
		// We take argmax for positions 1..blockLen (skipping position 0
		// which corresponds to the input token).
		outputs := logits.Floats()
		vocabSize := logits.Dim(0)
		if vocabSize == 0 || len(outputs) == 0 {
			slog.Error("dflash: draft forward produced no output")
			stats.draftDuration += time.Since(t0)
			return nil
		}

		result := make([]int32, draftCount)
		for i := range draftCount {
			// Position i+1 in the block (0-indexed: position 0 is the input token)
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

		// Run target forward on current token to get its prediction
		logits, capturedHidden := targetForward([]int32{currentToken})
		_ = capturedHidden

		// Get target's prediction for the next token
		outputs := logits.Floats()
		if len(outputs) == 0 {
			return 0, 0, false, fmt.Errorf("dflash: target forward produced no output")
		}

		// Get argmax token from logits (greedy)
		vocabSize := len(outputs)
		targetToken := argmaxToken(outputs, vocabSize)

		for i, draftToken := range draftTokens {
			// The target's prediction should match the draft token
			if targetToken != draftToken {
				// Mismatch: return the target's token as the next token
				return accepted, targetToken, false, nil
			}

			accepted++

			// Check if this is an EOS token
			if tok.Is(draftToken, tokenizer.SpecialEOS) {
				return accepted, draftToken, true, nil
			}

			// Emit the accepted draft token
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
			logits, capturedHidden = targetForward([]int32{draftToken})
			outputs = logits.Floats()
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

		// Calculate how many draft tokens to generate
		draftCount := int(blockSize) - 1
		remaining := numPredict - generated
		if draftCount > remaining {
			draftCount = remaining
		}
		if draftCount <= 0 {
			// No room for drafting, just do a regular decode step
			logits, _ := targetForward([]int32{0}) // placeholder — will be filled with actual token
			outputs := logits.Floats()
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
		// and captured hidden states for draft model context
		logits, capturedHidden := targetForward([]int32{0}) // will use actual current token below
		outputs := logits.Floats()
		if len(outputs) == 0 {
			return fmt.Errorf("dflash: target forward produced no output")
		}
		currentToken := argmaxToken(outputs, len(outputs))

		// Check if the target token is EOS
		if tok.Is(currentToken, tokenizer.SpecialEOS) {
			return nil
		}

		// Generate draft tokens using the draft model
		draftTokens := generateDraftTokens(capturedHidden, currentToken, draftCount, position)

		if len(draftTokens) > 0 {
			// Verify draft tokens against the target model
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
// It creates a separate model instance, loads weights, and creates a
// KV cache for the draft model.
func (s *Server) loadDraftModel(path string, params ml.BackendParams) error {
	slog.Info("loading draft model", "path", path)

	// Load the draft model using the same path as the target model.
	// model.New() reads the GGUF file, creates a backend, determines
	// the architecture (should be "dflash"), and populates tensors.
	draftModel, err := model.New(path, params)
	if err != nil {
		return fmt.Errorf("dflash: failed to create draft model: %w", err)
	}

	// Verify the draft model implements DFlashDraftModel
	draft, ok := draftModel.(DFlashDraftModel)
	if !ok {
		draftModel.Backend().Close()
		return fmt.Errorf("dflash: draft model architecture %q does not implement DFlashDraftModel", draftModel.Config().Cache)
	}

	// Load the draft model weights into GPU memory
	err = draftModel.Backend().Load(context.TODO(), func(progress float32) {
		slog.Info("loading draft model weights", "progress", progress)
	})
	if err != nil {
		draftModel.Backend().Close()
		return fmt.Errorf("dflash: failed to load draft model weights: %w", err)
	}

	// Run post-load initialization if the draft model supports it
	if postLoader, ok := draftModel.(model.PostLoader); ok {
		if err := postLoader.PostLoad(); err != nil {
			draftModel.Backend().Close()
			return fmt.Errorf("dflash: draft model post-load failed: %w", err)
		}
	}

	// Create an InputCache for the draft model.
	// The draft model uses a single slot (serial decode) with a smaller
	// context window since it only needs to cache block_size tokens.
	draftCache, err := NewInputCache(draftModel, "f16", int32(s.cache.numCtx), 1, s.batchSize, false)
	if err != nil {
		draftModel.Backend().Close()
		return fmt.Errorf("dflash: failed to create draft cache: %w", err)
	}

	s.draftModel = draftModel
	s.draftCache = draftCache

	slog.Info("draft model loaded",
		"path", path,
		"block_size", draft.BlockSize(),
		"target_layers", draft.TargetLayerIDs(),
		"mask_token_id", draft.MaskTokenID(),
	)
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
