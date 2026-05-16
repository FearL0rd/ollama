// Package dflash implements a DFlash block-diffusion draft model for speculative decoding.
// DFlash uses captured intermediate hidden states from the target model to generate
// draft tokens, which are then verified against the target model in a single batch.
package dflash

import (
	"fmt"
	"math"
	"sort"
	"strings"

	"github.com/ollama/ollama/fs"
	"github.com/ollama/ollama/kvcache"
	"github.com/ollama/ollama/ml"
	"github.com/ollama/ollama/ml/nn"
	"github.com/ollama/ollama/ml/nn/rope"
	"github.com/ollama/ollama/model"
	"github.com/ollama/ollama/model/input"
	"github.com/ollama/ollama/tokenizer"
)

func init() {
	model.Register("dflash", New)
}

type Options struct {
	hiddenSize           int
	numHeads             int
	numKVHeads           int
	headDim              int
	intermediateSize     int
	eps                  float32
	ropeBase             float32
	ropeScale            float32
	ropeType             string
	originalContextLength int
	slidingWindow        int

	// DFlash-specific
	targetLayerIDs []int
	maskTokenID    int32
	blockSize      int32
}

func (o Options) scale() float32 {
	return 1.0 / float32(math.Sqrt(float64(o.headDim)))
}

func (o Options) applyRotaryPosEmb(ctx ml.Context, states, positions ml.Tensor) ml.Tensor {
	opts := []func(*rope.Options){rope.WithTypeNeoX()}
	if o.ropeType == "yarn" {
		attnFactor := float32(1.0 / (1.0 + 0.1*math.Log(float64(o.ropeScale))))
		opts = append(opts,
			rope.WithOriginalContextLength(o.originalContextLength),
			rope.WithExtrapolationFactor(1.),
			rope.WithAttentionFactor(attnFactor),
		)
	}
	return nn.RoPE(ctx, states, positions, o.headDim, o.ropeBase, 1./o.ropeScale, opts...)
}

// Attention is a self-attention layer in the draft model.
type Attention struct {
	Query     *nn.Linear  `gguf:"attn_q"`
	QueryNorm *nn.RMSNorm `gguf:"attn_q_norm"`
	Key       *nn.Linear  `gguf:"attn_k"`
	KeyNorm   *nn.RMSNorm `gguf:"attn_k_norm"`
	Value     *nn.Linear  `gguf:"attn_v"`
	Output    *nn.Linear  `gguf:"attn_output"`
	Sliding   bool
}

func (a *Attention) Forward(ctx ml.Context, hiddenStates, positions ml.Tensor, cache kvcache.Cache, opts *Options) ml.Tensor {
	batchSize := hiddenStates.Dim(1)

	query := a.Query.Forward(ctx, hiddenStates)
	key := a.Key.Forward(ctx, hiddenStates)
	value := a.Value.Forward(ctx, hiddenStates)

	query = query.Reshape(ctx, opts.headDim, opts.numHeads, batchSize)
	key = key.Reshape(ctx, opts.headDim, opts.numKVHeads, batchSize)
	value = value.Reshape(ctx, opts.headDim, opts.numKVHeads, batchSize)

	query = a.QueryNorm.Forward(ctx, query, opts.eps)
	key = a.KeyNorm.Forward(ctx, key, opts.eps)

	query = opts.applyRotaryPosEmb(ctx, query, positions)
	key = opts.applyRotaryPosEmb(ctx, key, positions)

	attention := nn.Attention(ctx, query, key, value, 1./math.Sqrt(float64(opts.headDim)), cache)
	attention = attention.Reshape(ctx, attention.Dim(0)*attention.Dim(1), batchSize)
	return a.Output.Forward(ctx, attention)
}

// MLP is a feed-forward layer in the draft model.
type MLP struct {
	Gate *nn.Linear `gguf:"ffn_gate"`
	Up   *nn.Linear `gguf:"ffn_up"`
	Down *nn.Linear `gguf:"ffn_down"`
}

func (m *MLP) Forward(ctx ml.Context, hiddenStates ml.Tensor, opts *Options) ml.Tensor {
	hiddenStates = m.Gate.Forward(ctx, hiddenStates).SILU(ctx).Mul(ctx, m.Up.Forward(ctx, hiddenStates))
	return m.Down.Forward(ctx, hiddenStates)
}

// Layer is a single transformer layer in the draft model.
type Layer struct {
	Attention *Attention
	MLP       *MLP
	AttentionNorm *nn.RMSNorm `gguf:"attn_norm"`
	MLPNorm       *nn.RMSNorm `gguf:"ffn_norm"`
}

func (l *Layer) Forward(ctx ml.Context, hiddenStates, positions, outputs ml.Tensor, cache kvcache.Cache, opts *Options) ml.Tensor {
	residual := hiddenStates
	hiddenStates = l.AttentionNorm.Forward(ctx, hiddenStates, opts.eps)
	hiddenStates = l.Attention.Forward(ctx, hiddenStates, positions, cache, opts)

	if outputs != nil {
		hiddenStates = hiddenStates.Rows(ctx, outputs)
		residual = residual.Rows(ctx, outputs)
	}

	hiddenStates = hiddenStates.Add(ctx, residual)

	residual = hiddenStates
	hiddenStates = l.MLPNorm.Forward(ctx, hiddenStates, opts.eps)
	hiddenStates = l.MLP.Forward(ctx, hiddenStates, opts)
	return hiddenStates.Add(ctx, residual)
}

// Model is the DFlash draft model.
type Model struct {
	model.Base
	tokenizer.Tokenizer

	// Context projection: target hidden -> draft hidden
	ContextProjection *nn.Linear `gguf:"context_proj"`
	// Hidden norm after context projection
	HiddenNorm *nn.RMSNorm `gguf:"hidden_norm"`
	// Draft layers
	Layers []Layer `gguf:"blk"`
	// Final norm
	OutputNorm *nn.RMSNorm `gguf:"output_norm"`
	// Output projection
	Output *nn.Linear `gguf:"output,alt:token_embd"`
	// Token embedding
	TokenEmbedding *nn.Embedding `gguf:"token_embd"`

	*Options
}

var _ model.Model = (*Model)(nil)

// New creates a new DFlash draft model.
func New(c fs.Config) (model.Model, error) {
	m := Model{
		Layers: make([]Layer, c.Uint("block_count")),
		Options: &Options{
			hiddenSize:           int(c.Uint("hidden_size")),
			numHeads:             int(c.Uint("num_attention_heads")),
			numKVHeads:           int(c.Uint("num_key_value_heads")),
			headDim:              int(c.Uint("head_dim")),
			intermediateSize:     int(c.Uint("intermediate_size")),
			eps:                  c.Float("rms_norm_eps"),
			ropeBase:             c.Float("rope_theta"),
			ropeScale:            1.0,
			originalContextLength: int(c.Uint("max_position_embeddings")),
			slidingWindow:        int(c.Uint("sliding_window")),
		},
	}

	m.Tokenizer = tokenizer.NewBytePairEncoding(
		&tokenizer.Vocabulary{
			Values: c.Strings("tokenizer.ggml.tokens"),
			Types:  c.Ints("tokenizer.ggml.token_type"),
			Merges: c.Strings("tokenizer.ggml.merges"),
			AddBOS: c.Bool("tokenizer.ggml.add_bos_token", true),
			BOS:    []int32{int32(c.Uint("tokenizer.ggml.bos_token_id"))},
			AddEOS: c.Bool("tokenizer.ggml.add_eos_token", false),
			EOS: append(
				[]int32{int32(c.Uint("tokenizer.ggml.eos_token_id"))},
				c.Ints("tokenizer.ggml.eos_token_ids")...,
			),
		},
		`(?i:'s|'t|'re|'ve|'m|'ll|'d)|[^\r\n\p{L}\p{N}]?\p{L}+|\p{N}| ?[^\s\p{L}\p{N}]+[\r\n]*|\s*[\r\n]+|\s+(?!\S)|\s+`,
	)

	if m.numKVHeads == 0 {
		m.numKVHeads = m.numHeads
	}
	if m.headDim == 0 {
		m.headDim = m.hiddenSize / m.numHeads
	}
	if m.eps == 0 {
		m.eps = 1e-6
	}
	if m.ropeBase == 0 {
		m.ropeBase = 1000000
	}

	// Parse DFlash-specific config from GGUF metadata
	targetLayerIDsInt32 := c.Ints("dflash_config.target_layer_ids")
	m.targetLayerIDs = make([]int, len(targetLayerIDsInt32))
	for i, v := range targetLayerIDsInt32 {
		m.targetLayerIDs[i] = int(v)
	}
	m.maskTokenID = int32(c.Uint("dflash_config.mask_token_id"))
	m.blockSize = int32(c.Uint("block_size"))
	if m.blockSize == 0 {
		m.blockSize = 16
	}

	ropeType := c.String("rope_type")
	if ropeType == "" {
		ropeType = c.String("rope_scaling.type")
	}
	m.ropeType = strings.ToLower(ropeType)
	if m.ropeType == "yarn" {
		m.ropeScale = c.Float("rope_scaling.factor", 1)
	}

	return &m, nil
}

// Forward implements model.Model.
func (m *Model) Forward(ctx ml.Context, batch input.Batch) (ml.Tensor, error) {
	positions := ctx.Input().FromInts(batch.Positions, len(batch.Positions))

	hiddenStates := m.TokenEmbedding.Forward(ctx, batch.Inputs)

	for i, layer := range m.Layers {
		if m.Cache != nil {
			m.Cache.SetLayer(i)
		}

		var outputs ml.Tensor
		if i == len(m.Layers)-1 {
			outputs = batch.Outputs
		}

		hiddenStates = layer.Forward(ctx, hiddenStates, positions, outputs, m.Cache, m.Options)
	}

	hiddenStates = m.OutputNorm.Forward(ctx, hiddenStates, m.eps)
	return m.Output.Forward(ctx, hiddenStates), nil
}

// Shift implements model.ShiftingModel for context window shifting.
func (m *Model) Shift(ctx ml.Context, layer int, key, shift ml.Tensor) (ml.Tensor, error) {
	return m.applyRotaryPosEmb(ctx, key, shift), nil
}

// TargetLayerIDs returns the target model layer IDs to capture hidden states from.
func (m *Model) TargetLayerIDs() []int {
	return m.targetLayerIDs
}

// BlockSize returns the number of draft tokens to generate per iteration.
func (m *Model) BlockSize() int32 {
	return m.blockSize
}

// MaskTokenID returns the mask token ID used for padding in block diffusion.
func (m *Model) MaskTokenID() int32 {
	return m.maskTokenID
}

// ForwardDFlashContext projects captured target hidden states into the draft model's
// hidden space. This is the entry point for the DFlash speculative decode loop.
func (m *Model) ForwardDFlashContext(ctx ml.Context, targetHidden ml.Tensor) ml.Tensor {
	hidden := m.ContextProjection.Forward(ctx, targetHidden)
	hidden = m.HiddenNorm.Forward(ctx, hidden, m.eps)
	return hidden
}

// Validate checks the model configuration.
func (m *Model) Validate() error {
	if m.hiddenSize <= 0 {
		return fmt.Errorf("dflash: invalid hidden_size: %d", m.hiddenSize)
	}
	if m.numHeads <= 0 {
		return fmt.Errorf("dflash: invalid num_attention_heads: %d", m.numHeads)
	}
	if len(m.targetLayerIDs) == 0 {
		return fmt.Errorf("dflash: target_layer_ids is required")
	}
	if !sort.IntsAreSorted(m.targetLayerIDs) {
		return fmt.Errorf("dflash: target_layer_ids must be sorted")
	}
	if m.blockSize <= 0 {
		return fmt.Errorf("dflash: invalid block_size: %d", m.blockSize)
	}
	return nil
}
