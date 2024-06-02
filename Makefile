-include .env

.PHONY: all test deploy

help:
	@echo "Useage:"
	@echo " make deploy [ARGS=...]"

build:; forge build --via-ir

test:; forge test --via-ir

anvil :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1

NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --account $(ANVIL_ACCOUNT) --sender $(ANVIL_SENDER) --broadcast 

ifeq ($(findstring --network sepolia, $(ARGS)), --network sepolia)
	NETWORK_ARGS := --rpc-url $(SEPOLIA_RPC_URL) --account $(SEPOLIA_ACCOUNT) --sender $(SEPOLIA_SENDER) --private-key $(SEPOLIA_DEPLOYER_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) --legacy -vvvv
endif
ifeq ($(findstring --network sepolia_no_verify, $(ARGS)), --network sepolia_no_verify)
	NETWORK_ARGS := --rpc-url $(SEPOLIA_RPC_URL) --account $(SEPOLIA_ACCOUNT) --sender $(SEPOLIA_SENDER) --private-key $(SEPOLIA_DEPLOYER_KEY) --broadcast -vvvv --legacy
endif
ifeq ($(findstring --network sepolia_only_verify, $(ARGS)), --network sepolia)
	NETWORK_ARGS := --rpc-url $(SEPOLIA_RPC_URL) --account $(SEPOLIA_ACCOUNT) --sender $(SEPOLIA_SENDER) --private-key $(SEPOLIA_DEPLOYER_KEY) --resume --verify --etherscan-api-key $(ETHERSCAN_API_KEY) --legacy -vvvv
endif
deploy:; forge script script/DeployRaffle.s.sol:DeployRaffle $(NETWORK_ARGS)