from .base import *
from deepspeed.model_implementations.transformers.ds_opt import DeepSpeedOPTInference
from deepspeed.ops.transformer.inference.config import DeepSpeedInferenceConfig


class DS_OPTContainer(BaseTransformerContainer):
    def __init__(self, policy):
        super().__init__(policy)

        self.attn_linear_layer = False
        self.mlp_linear_layer = False
        self.scale_attention = True
        self.layer_norm_eps = 1e-5
        self.pre_layer_norm = True

    def create_config(self):
        self.config = DeepSpeedInferenceConfig(hidden_size=self.hidden_size,
                                               heads=self.num_attention_heads,
                                               layer_norm_eps=self.layer_norm_eps,
                                               fp16=self.fp16,
                                               pre_layer_norm=self.pre_layer_norm,
                                               mp_size=self.mp_size)
        return self.config

    def create_module(self, config=None):
        _config = config if config is not None else self.config
        self.module = DeepSpeedOPTInference(_config, mp_group=self.mp_group)
        self.module.config.scale_attention = self.scale_attention
        return self.module

    def transpose(self):
        # GPT2 does not need a transpose so override and pass
        pass