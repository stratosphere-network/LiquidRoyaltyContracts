import { BigInt, Bytes } from "@graphprotocol/graph-ts"
import {
  Deposit as DepositEvent,
  Withdraw as WithdrawEvent,
  Transfer as TransferEvent,
  SpilloverReceived as SpilloverReceivedEvent,
  BackstopProvided as BackstopProvidedEvent,
  JuniorRebaseExecuted as JuniorRebaseExecutedEvent,
  CooldownInitiated as CooldownInitiatedEvent,
  WithdrawalPenaltyCharged as WithdrawalPenaltyChargedEvent,
  VaultValueUpdated as VaultValueUpdatedEvent,
  FeesCollected as FeesCollectedEvent,
  BGTClaimed as BGTClaimedEvent
} from "../generated/JuniorVault/JuniorVault"
import {
  User,
  Deposit,
  Withdrawal,
  Transfer,
  SpilloverReceived,
  BackstopProvided,
  JuniorRebase,
  Cooldown,
  Penalty,
  VaultValue,
  FeeCollection,
  BGTClaim,
  ProtocolStats
} from "../generated/schema"

function getOrCreateUser(address: Bytes): User {
  let user = User.load(address.toHexString())
  if (user == null) {
    user = new User(address.toHexString())
    user.totalDeposited = BigInt.fromI32(0)
    user.totalWithdrawn = BigInt.fromI32(0)
    user.lastActivityTimestamp = BigInt.fromI32(0)
    user.save()
    
    let stats = getOrCreateProtocolStats()
    stats.totalUsers = stats.totalUsers + 1
    stats.save()
  }
  return user
}

function getOrCreateProtocolStats(): ProtocolStats {
  let stats = ProtocolStats.load("protocol")
  if (stats == null) {
    stats = new ProtocolStats("protocol")
    stats.totalDeposits = BigInt.fromI32(0)
    stats.totalWithdrawals = BigInt.fromI32(0)
    stats.totalSpilloverReceived = BigInt.fromI32(0)
    stats.totalBackstopProvided = BigInt.fromI32(0)
    stats.totalUsers = 0
    stats.lastUpdateTimestamp = BigInt.fromI32(0)
    stats.save()
  }
  return stats
}

export function handleDeposit(event: DepositEvent): void {
  let deposit = new Deposit(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  )
  
  let user = getOrCreateUser(event.params.owner)
  
  deposit.user = user.id
  deposit.assets = event.params.assets
  deposit.shares = event.params.shares
  deposit.timestamp = event.block.timestamp
  deposit.blockNumber = event.block.number
  deposit.transactionHash = event.transaction.hash
  deposit.save()
  
  user.totalDeposited = user.totalDeposited.plus(event.params.assets)
  user.lastActivityTimestamp = event.block.timestamp
  user.save()
  
  let stats = getOrCreateProtocolStats()
  stats.totalDeposits = stats.totalDeposits.plus(event.params.assets)
  stats.lastUpdateTimestamp = event.block.timestamp
  stats.save()
}

export function handleWithdraw(event: WithdrawEvent): void {
  let withdrawal = new Withdrawal(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  )
  
  let user = getOrCreateUser(event.params.owner)
  
  withdrawal.user = user.id
  withdrawal.assets = event.params.assets
  withdrawal.shares = event.params.shares
  withdrawal.timestamp = event.block.timestamp
  withdrawal.blockNumber = event.block.number
  withdrawal.transactionHash = event.transaction.hash
  withdrawal.save()
  
  user.totalWithdrawn = user.totalWithdrawn.plus(event.params.assets)
  user.lastActivityTimestamp = event.block.timestamp
  user.save()
  
  let stats = getOrCreateProtocolStats()
  stats.totalWithdrawals = stats.totalWithdrawals.plus(event.params.assets)
  stats.lastUpdateTimestamp = event.block.timestamp
  stats.save()
}

export function handleTransfer(event: TransferEvent): void {
  let transfer = new Transfer(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  )
  
  transfer.from = event.params.from
  transfer.to = event.params.to
  transfer.value = event.params.value
  transfer.timestamp = event.block.timestamp
  transfer.blockNumber = event.block.number
  transfer.transactionHash = event.transaction.hash
  transfer.save()
}

export function handleSpilloverReceived(event: SpilloverReceivedEvent): void {
  let spillover = new SpilloverReceived(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  )
  
  spillover.amount = event.params.amount
  spillover.fromSenior = event.params.fromSenior
  spillover.timestamp = event.block.timestamp
  spillover.blockNumber = event.block.number
  spillover.transactionHash = event.transaction.hash
  spillover.save()
  
  let stats = getOrCreateProtocolStats()
  stats.totalSpilloverReceived = stats.totalSpilloverReceived.plus(event.params.amount)
  stats.lastUpdateTimestamp = event.block.timestamp
  stats.save()
}

export function handleBackstopProvided(event: BackstopProvidedEvent): void {
  let backstop = new BackstopProvided(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  )
  
  backstop.amount = event.params.amount
  backstop.toSenior = event.params.toSenior
  backstop.timestamp = event.block.timestamp
  backstop.blockNumber = event.block.number
  backstop.transactionHash = event.transaction.hash
  backstop.save()
  
  let stats = getOrCreateProtocolStats()
  stats.totalBackstopProvided = stats.totalBackstopProvided.plus(event.params.amount)
  stats.lastUpdateTimestamp = event.block.timestamp
  stats.save()
}

export function handleJuniorRebase(event: JuniorRebaseExecutedEvent): void {
  let rebase = new JuniorRebase(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  )
  
  rebase.newValue = event.params.newValue
  rebase.effectiveReturn = event.params.effectiveReturn
  rebase.timestamp = event.block.timestamp
  rebase.blockNumber = event.block.number
  rebase.transactionHash = event.transaction.hash
  rebase.save()
}

export function handleCooldownInitiated(event: CooldownInitiatedEvent): void {
  let cooldown = new Cooldown(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  )
  
  let user = getOrCreateUser(event.params.user)
  
  cooldown.user = user.id
  cooldown.timestamp = event.params.timestamp
  cooldown.blockNumber = event.block.number
  cooldown.transactionHash = event.transaction.hash
  cooldown.save()
}

export function handleWithdrawalPenalty(event: WithdrawalPenaltyChargedEvent): void {
  let penalty = new Penalty(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  )
  
  let user = getOrCreateUser(event.params.user)
  
  penalty.user = user.id
  penalty.penalty = event.params.penalty
  penalty.timestamp = event.block.timestamp
  penalty.blockNumber = event.block.number
  penalty.transactionHash = event.transaction.hash
  penalty.save()
}

export function handleVaultValueUpdated(event: VaultValueUpdatedEvent): void {
  let vaultValue = new VaultValue(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  )
  
  vaultValue.oldValue = event.params.oldValue
  vaultValue.newValue = event.params.newValue
  vaultValue.profitBps = event.params.profitBps
  vaultValue.timestamp = event.block.timestamp
  vaultValue.blockNumber = event.block.number
  vaultValue.transactionHash = event.transaction.hash
  vaultValue.save()
}

export function handleFeesCollected(event: FeesCollectedEvent): void {
  let fees = new FeeCollection(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  )
  
  fees.managementFee = event.params.managementFee
  fees.performanceFee = event.params.performanceFee
  fees.timestamp = event.block.timestamp
  fees.blockNumber = event.block.number
  fees.transactionHash = event.transaction.hash
  fees.save()
}

export function handleBGTClaimed(event: BGTClaimedEvent): void {
  let claim = new BGTClaim(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  )
  
  claim.recipient = event.params.recipient
  claim.amount = event.params.amount
  claim.timestamp = event.block.timestamp
  claim.blockNumber = event.block.number
  claim.transactionHash = event.transaction.hash
  claim.save()
}

