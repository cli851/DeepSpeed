from .base import *
from deepspeed.model_implementations.transformers.ds_gpt import DeepSpeedGPTInference
from deepspeed.ops.transformer.inference.config import DeepSpeedInferenceConfig


class DS_GPTJContainer(BaseTransformerContainer):
    def __init__(self, policy):
        super().__init__(policy)

        self.attn_linear_layer = True
        self.mlp_linear_layer = True
        self.scale_attention = True
        self.layer_norm_eps = 1e-05
        self.pre_layer_norm = True
        self.rotary_dim = 64
        self.window_size = 1
        self.mlp_after_attn = False
        # self.fp16 is in the base.py and set_dtpye() will set it from the replace_with_policy() call site.

        #self.tensors.append(alibi)
        #self.tensors = [self.qkvw, self.qkvb, self.dense_w, self.dense_b, self._h4h_w, self._h4h_b, self._4hh_w, self._4hh_b, self.attn_nw, self.attn_nb, self.input_nw, self.input_nb, self.new_tensor_type]
        #self.config = {'hidden_size': self.hidden_size, 'num_attention_heads': self.num_attention_heads, 'attn_linear_layer': self.attn_linear_layer, 'mlp_linear_layer': self.mlp_linear_layer, 'scale_attention': self.scale_attention, 'megatron_v2': self.megatron_v2, 'mp_size': self.mp_size}

    def create_config(self):
        self.config = DeepSpeedInferenceConfig(hidden_size=self.hidden_size,
                                               heads=self.num_attention_heads,
                                               layer_norm_eps=self.layer_norm_eps,
                                               fp16=self.fp16,
                                               pre_layer_norm=self.pre_layer_norm,
                                               mp_size=self.mp_size,
                                               mlp_after_attn=self.mlp_after_attn,
                                               window_size=self.window_size,
                                               rotary_dim=self.rotary_dim,
                                               scale_attention=self.scale_attention)
        return self.config

    def create_module(self, config=None):
        _config = config if config is not None else self.config
        self.module = DeepSpeedGPTInference(_config, mp_group=self.mp_group)
        self.module.config.scale_attention = self.scale_attention
        return self.module