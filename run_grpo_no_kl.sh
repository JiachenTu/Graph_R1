while getopts "p:m:d:" opt; do
  case $opt in
    p) path=$OPTARG ;;
    m) model=$OPTARG ;;
    d) dataset=$OPTARG ;;
    *) echo "Invalid option"; exit 1 ;;
  esac
done

shift $((OPTIND - 1))

export CUDA_VISIBLE_DEVICES=4,5,6,7
export VLLM_ATTENTION_BACKEND=XFORMERS
export BASE_MODEL="${path}"
export PROJECT_NAME='Graph-R1'
export EXPERIMENT_NAME="${model}_${dataset}_grpo_no_kl"
export HYDRA_FULL_ERROR=1
export CUDA_LAUNCH_BLOCKING=1
export HF_HOME="/srv/local/shared/temp/tmp1/jtu9/hf_cache"
export HF_DATASETS_CACHE="$HF_HOME/datasets"
export TRANSFORMERS_CACHE="$HF_HOME/transformers"
set -x

ray stop
ray start --head

python3 -m verl.trainer.main_ppo \
    algorithm.adv_estimator=grpo \
    data.train_files=datasets/"${dataset}"/processed/train.parquet \
    data.val_files=datasets/"${dataset}"/processed/test.parquet \
    data.train_batch_size=64 \
    data.max_prompt_length=4096 \
    data.max_response_length=4096 \
    data.max_start_length=4096 \
    data.max_tool_response_length=4096 \
    actor_rollout_ref.model.path=$BASE_MODEL \
    actor_rollout_ref.actor.optim.lr=5e-7 \
    actor_rollout_ref.model.use_remove_padding=False \
    actor_rollout_ref.actor.ppo_mini_batch_size=32 \
    actor_rollout_ref.actor.ppo_micro_batch_size_per_gpu=1 \
    actor_rollout_ref.actor.use_kl_loss=False \
    actor_rollout_ref.actor.kl_loss_coef=0 \
    actor_rollout_ref.actor.kl_loss_type=low_var_kl \
    actor_rollout_ref.model.enable_gradient_checkpointing=True \
    actor_rollout_ref.actor.fsdp_config.param_offload=False \
    actor_rollout_ref.actor.fsdp_config.optimizer_offload=True \
    actor_rollout_ref.rollout.log_prob_micro_batch_size_per_gpu=2 \
    actor_rollout_ref.rollout.tensor_model_parallel_size=4 \
    actor_rollout_ref.rollout.name=vllm \
    actor_rollout_ref.rollout.gpu_memory_utilization=0.5 \
    actor_rollout_ref.rollout.n_repeat=5 \
    actor_rollout_ref.ref.log_prob_micro_batch_size_per_gpu=2 \
    actor_rollout_ref.ref.fsdp_config.param_offload=True \
    algorithm.kl_ctrl.kl_coef=0 \
    trainer.critic_warmup=0 \
    trainer.logger=['console','wandb'] \
    trainer.project_name=$PROJECT_NAME \
    trainer.experiment_name=$EXPERIMENT_NAME \
    trainer.n_gpus_per_node=4 \
    trainer.nnodes=1 \
    trainer.save_freq=-1 \
    trainer.test_freq=5 \
    trainer.total_epochs=1 \
    tool.env='search' $@
