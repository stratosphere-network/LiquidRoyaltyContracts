// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// Auto-compound, router, and helper imports removed

/**
 * @title Dividend
 * @dev A contract for distributing ERC20 tokens as dividends to multiple recipients
 *      Supports batch transfers for gas efficiency when dealing with large recipient lists
 *      Includes emergency functions, fee collection, and comprehensive event logging
 */
contract Dividend is
    Initializable,
    OwnableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;

    // Events
    event DividendDistributed(
        uint256 dividendId,
        address indexed token,
        string dividendName,
        uint256 totalAmount,
        uint256 feeAmount,
        uint256 netAmount,
        uint256 recipientCount,
        uint256 timestamp
    );

    event BatchTransferCompleted(
        address indexed token,
        uint256 batchIndex,
        uint256 recipientsInBatch,
        uint256 amountPerBatch
    );

    event EmergencyWithdrawal(
        address indexed token,
        address indexed to,
        uint256 amount
    );

    event FeeCollected(
        uint256 dividendId,
        address indexed token,
        address indexed feeAddress,
        uint256 feeAmount,
        uint256 feePercentage
    );

    event ManagementFeeCollected(
        uint256 dividendId,
        address indexed token,
        address indexed managementFeeAddress,
        uint256 managementFeeAmount,
        uint256 managementFeePercentage
    );

    event FeeAddressUpdated(
        address indexed oldFeeAddress,
        address indexed newFeeAddress
    );

    event FeePercentageUpdated(
        uint256 oldFeePercentage,
        uint256 newFeePercentage
    );

    // Distribution approval events
    event DistributionProposed(
        uint256 indexed distributionId,
        address indexed proposer,
        string name,
        address indexed token,
        uint256 totalAmount,
        uint256 recipientCount,
        uint256 timestamp
    );

    event DistributionApproved(
        uint256 indexed distributionId,
        address indexed approver,
        uint256 timestamp
    );

    event DistributionRejected(
        uint256 indexed distributionId,
        address indexed rejector,
        uint256 timestamp
    );

    event DistributionExecuted(
        uint256 indexed distributionId,
        uint256 dividendId,
        uint256 timestamp
    );

    event DistributionCancelled(
        uint256 indexed distributionId,
        address indexed canceller,
        uint256 timestamp
    );

    // Contract capability events
    event ContractCapabilities(
        bool hasApprovalSystem,
        bool hasProposalSystem,
        uint256 maxBatchSize,
        uint256 defaultExpiry,
        string[] availableFunctions
    );

    // Auto-compound events removed

    // Structs
    struct DividendInfo {
        string name;
        address token;
        uint256 totalAmount;
        uint256 feeAmount;
        uint256 netAmount;
        uint256 recipientCount;
        uint256 timestamp;
        bool completed;
    }

    struct DistributionProposal {
        uint256 distributionId;
        string name;
        address token;
        address[] recipients;
        uint256[] amounts;
        address proposer;
        uint256 timestamp;
        DistributionStatus status;
        address approver;
        uint256 actionTimestamp;
        uint256 expiry; // Optional expiry timestamp
    }

    enum DistributionStatus {
        Pending,
        Approved,
        Rejected,
        Executed,
        Cancelled
    }

    // State variables
    mapping(uint256 => DividendInfo) public dividendHistory;
    uint256 public dividendCounter;
    uint256 public maxBatchSize;
    
    // Fee-related state variables
    uint256 public feePercentage; // Fee percentage in basis points (10000 = 100%)
    address public feeAddress; // Address to receive fees
    address public managementFeeAddress; // Address to receive management fee (fixed bps)
    uint256 private constant MANAGEMENT_FEE_BPS = 10; // 0.1%

    // Distribution approval state variables
    mapping(uint256 => DistributionProposal) public distributionProposals;
    uint256 public distributionCounter;
    uint256[] private pendingDistributionIds;
    mapping(uint256 => uint256) private pendingDistributionIndex; // distributionId => index in pendingDistributionIds
    uint256 public distributionExpiry; // Default expiry time in seconds (0 = no expiry)

    // Auto-compound state removed

    // EIP-712 constants removed

    // Role definitions
    bytes32 public constant DIVIDEND_APPROVER_ROLE = keccak256("DIVIDEND_APPROVER_ROLE");
    bytes32 public constant DISTRIBUTION_PROPOSER_ROLE = keccak256("DISTRIBUTION_PROPOSER_ROLE");

    /**
     * @dev Initializes the dividend contract
     * @param _maxBatchSize Maximum number of recipients per batch (recommended: 100-200)
     * @param _feePercentage Initial fee percentage in basis points (e.g., 250 = 2.5%)
     * @param _feeAddress Initial address to receive fees
     * @param _managementFeeAddress Address to receive management fees
     */

    function initialize(
        uint256 _maxBatchSize,
        uint256 _feePercentage,
        address _feeAddress,
        address _managementFeeAddress
    ) public initializer {
        __Ownable_init(msg.sender);
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        require(_maxBatchSize > 0, "Batch size must be greater than 0");
        require(_feePercentage <= 10000, "Fee percentage cannot exceed 100%");
        require(_feeAddress != address(0), "Invalid fee address");
        require(_managementFeeAddress != address(0), "Invalid management fee address");

        maxBatchSize = _maxBatchSize;
        feePercentage = _feePercentage;
        feeAddress = _feeAddress;
        managementFeeAddress = _managementFeeAddress;
        dividendCounter = 0;
        distributionCounter = 0;
        distributionExpiry = 0; // Default: no expiry
        
        // Emit contract capabilities for frontend
        string[] memory availableFunctions = new string[](8);
        availableFunctions[0] = "distributeDividend";
        availableFunctions[1] = "proposeDistribution";
        availableFunctions[2] = "approveDistribution";
        availableFunctions[3] = "rejectDistribution";
        availableFunctions[4] = "cancelDistribution";
        availableFunctions[5] = "getPendingDistributions";
        availableFunctions[6] = "getAllPendingDistributions";
        availableFunctions[7] = "getDistributions";
        
        emit ContractCapabilities(
            true,  // hasApprovalSystem
            true,  // hasProposalSystem
            _maxBatchSize,
            distributionExpiry,
            availableFunctions
        );
        // no storage writes for domain here; computed on demand
    }

    /**
     * @dev Calculates the fee amount based on total amount and fee percentage
     * @param totalAmount The total amount to calculate fee from
     * @return The calculated fee amount
     */
    function calculateFee(uint256 totalAmount) public view returns (uint256) {
        return (totalAmount * feePercentage) / 10000;
    }

    /**
     * @dev Distributes tokens to multiple recipients in batches with fee deduction
     * @param name Name of the dividend (e.g., "Quarter 1 dividend")
     * @param token Address of the ERC20 token to distribute
     * @param recipients Array of recipient addresses
     * @param amounts Array of amounts corresponding to each recipient
     */
    function distributeDividend(
        string memory name,
        address token,
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external onlyOwner nonReentrant {
        require(bytes(name).length > 0, "Dividend name required");
        require(token != address(0), "Invalid token address");
        require(recipients.length == amounts.length, "Arrays length mismatch");
        require(recipients.length > 0, "No recipients provided");

        
        // Calculate totals
        uint256 totalDividendAmount = _sumAmounts(amounts);
        uint256 feeAmount = calculateFee(totalDividendAmount);
        uint256 managementFeeAmount = (totalDividendAmount * MANAGEMENT_FEE_BPS) / 10000;
        uint256 totalAmountNeeded = totalDividendAmount + feeAmount + managementFeeAmount;

        require(
            IERC20(token).balanceOf(address(this)) >= totalAmountNeeded,
            "Insufficient token balance"
        );

        // Create the record and emit events
        uint256 currentDividendId = _createDividendRecord(
            name,
            token,
            totalAmountNeeded,
            feeAmount,
            totalDividendAmount,
            recipients.length
        );

        _processBatches(token, recipients, amounts);

        // Mark dividend as completed
        dividendHistory[currentDividendId].completed = true;
    }

    /**
     * @dev Distributes equal amounts to all recipients with fee deduction
     * @param name Name of the dividend (e.g., "Quarter 1 dividend")
     * @param token Address of the ERC20 token to distribute
     * @param recipients Array of recipient addresses
     * @param amountPerRecipient Amount to send to each recipient
     */
    function distributeEqualDividend(
        string memory name,
        address token,
        address[] calldata recipients,
        uint256 amountPerRecipient
    ) external onlyOwner nonReentrant {
        require(bytes(name).length > 0, "Dividend name required");
        require(token != address(0), "Invalid token address");
        require(recipients.length > 0, "No recipients provided");
        require(amountPerRecipient > 0, "Amount must be greater than 0");

        
        // Calculate totals
        uint256 totalDividendAmount = recipients.length * amountPerRecipient;
        uint256 feeAmount = calculateFee(totalDividendAmount);
        uint256 managementFeeAmount = (totalDividendAmount * MANAGEMENT_FEE_BPS) / 10000;
        uint256 totalAmountNeeded = totalDividendAmount + feeAmount + managementFeeAmount;

        require(
            IERC20(token).balanceOf(address(this)) >= totalAmountNeeded,
            "Insufficient token balance"
        );

        // Create the record and emit events
        uint256 currentDividendId = _createDividendRecord(
            name,
            token,
            totalAmountNeeded,
            feeAmount,
            totalDividendAmount,
            recipients.length
        );

        _processBatchesEqual(token, recipients, amountPerRecipient);

        // Mark dividend as completed
        dividendHistory[currentDividendId].completed = true;
    }

    /**
     * @dev Updates the fee percentage
     * @param _feePercentage New fee percentage in basis points (e.g., 250 = 2.5%)
     */
    function setFeePercentage(uint256 _feePercentage) external onlyOwner {
        require(_feePercentage <= 10000, "Fee percentage cannot exceed 100%");
        
        uint256 oldFeePercentage = feePercentage;
        feePercentage = _feePercentage;
        
        emit FeePercentageUpdated(oldFeePercentage, _feePercentage);
    }

    /**
     * @dev Updates the fee address
     * @param _feeAddress New address to receive fees
     */
    function setFeeAddress(address _feeAddress) external onlyOwner {
        require(_feeAddress != address(0), "Invalid fee address");
        
        address oldFeeAddress = feeAddress;
        feeAddress = _feeAddress;
        
        emit FeeAddressUpdated(oldFeeAddress, _feeAddress);
    }

    /**
     * @dev Updates the maximum batch size for gas optimization
     * @param _maxBatchSize New maximum batch size
     */
    function setMaxBatchSize(uint256 _maxBatchSize) external onlyOwner {
        require(_maxBatchSize > 0, "Batch size must be greater than 0");
        maxBatchSize = _maxBatchSize;
    }

    /**
     * @dev Sets or clears the ERC-4626 vault for a given token.
     *      When set, recipients who opt-in will receive deposits into the vault
     *      instead of direct token transfers during distribution.
     */
    // Vault functions removed

    /**
     * @dev Sets an external auto-compound router to offload vault logic and reduce stack usage.
     */
    // Router setter removed

    /**
     * @dev Sets the external payout helper used to offload batch transfers (optional).
     */
    // Payout helper setter removed

    /**
     * @dev Recipient sets their auto-compound preference for a token.
     */
    // Auto-compound preference function removed

    // --- EIP-712 typed data consent for gasless opt-in ---

    // EIP-712 helpers removed

    // EIP-712 setter removed

    // EIP-712 batch setter removed

    /**
     * @dev Returns the configured vault for a token (zero if none)
     */
    // Vault view removed

    /**
     * @dev Returns whether a user has opted in to auto-compounding for a token
     */
    // Auto-compound view removed

    // --- Internal helpers to reduce stack depth in distribution functions ---
    function _createDividendRecord(
        string memory name,
        address token,
        uint256 totalAmountNeeded,
        uint256 feeAmount,
        uint256 totalDividendAmount,
        uint256 recipientCount
    ) internal returns (uint256 currentDividendId) {
        currentDividendId = dividendCounter++;
        dividendHistory[currentDividendId] = DividendInfo({
            name: name,
            token: token,
            totalAmount: totalAmountNeeded,
            feeAmount: feeAmount,
            netAmount: totalDividendAmount,
            recipientCount: recipientCount,
            timestamp: block.timestamp,
            completed: false
        });
        if (feeAmount > 0) {
            IERC20(token).safeTransfer(feeAddress, feeAmount);
            emit FeeCollected(currentDividendId, token, feeAddress, feeAmount, feePercentage);
        }
        uint256 managementFeeAmount = (totalDividendAmount * MANAGEMENT_FEE_BPS) / 10000;
        if (managementFeeAmount > 0) {
            IERC20(token).safeTransfer(managementFeeAddress, managementFeeAmount);
            emit ManagementFeeCollected(
                currentDividendId,
                token,
                managementFeeAddress,
                managementFeeAmount,
                MANAGEMENT_FEE_BPS
            );
        }
        emit DividendDistributed(
            currentDividendId,
            token,
            name,
            totalAmountNeeded,
            feeAmount,
            totalDividendAmount,
            recipientCount,
            block.timestamp
        );
    }

    function getManagementFeeConfiguration() external view returns (uint256, address) {
        return (MANAGEMENT_FEE_BPS, managementFeeAddress);
    }
    function _processBatches(
        address token,
        address[] calldata recipients,
        uint256[] calldata amounts
    ) internal {
        uint256 count = recipients.length;
        uint256 batchCount = (count + maxBatchSize - 1) / maxBatchSize;
        for (uint256 batchIndex = 0; batchIndex < batchCount; batchIndex++) {
            uint256 startIndex = batchIndex * maxBatchSize;
            uint256 endIndex = startIndex + maxBatchSize;
            if (endIndex > count) {
                endIndex = count;
            }

            uint256 batchAmount = 0;
            for (uint256 i = startIndex; i < endIndex; i++) {
                address recipient = recipients[i];
                require(recipient != address(0), "Invalid recipient address");
                uint256 amount = amounts[i];
                require(amount > 0, "Amount must be greater than 0");

                _handlePayout(token, recipient, amount);
                batchAmount += amount;
            }

            emit BatchTransferCompleted(
                token,
                batchIndex,
                endIndex - startIndex,
                batchAmount
            );
        }
    }

    function _processBatchesEqual(
        address token,
        address[] calldata recipients,
        uint256 amountPerRecipient
    ) internal {
        uint256 count = recipients.length;
        uint256 batchCount = (count + maxBatchSize - 1) / maxBatchSize;
        for (uint256 batchIndex = 0; batchIndex < batchCount; batchIndex++) {
            uint256 startIndex = batchIndex * maxBatchSize;
            uint256 endIndex = startIndex + maxBatchSize;
            if (endIndex > count) {
                endIndex = count;
            }

            for (uint256 i = startIndex; i < endIndex; i++) {
                address recipient = recipients[i];
                require(recipient != address(0), "Invalid recipient address");
                _handlePayout(token, recipient, amountPerRecipient);
            }

            emit BatchTransferCompleted(
                token,
                batchIndex,
                endIndex - startIndex,
                (endIndex - startIndex) * amountPerRecipient
            );
        }
    }

    function _sumAmounts(uint256[] calldata amounts) internal pure returns (uint256 total) {
        uint256 len = amounts.length;
        for (uint256 i = 0; i < len; i++) {
            total += amounts[i];
        }
    }

    function _handlePayout(
        address token,
        address recipient,
        uint256 amount
    ) internal {
        IERC20(token).safeTransfer(recipient, amount);
    }

    /**
     * @dev Emergency function to withdraw tokens from the contract
     * @param token Address of the token to withdraw
     * @param to Address to send the tokens to
     * @param amount Amount of tokens to withdraw
     */
    function emergencyWithdraw(
        address token,
        address to,
        uint256 amount
    ) external onlyOwner {
        require(token != address(0), "Invalid token address");
        require(to != address(0), "Invalid recipient address");
        require(amount > 0, "Amount must be greater than 0");

        IERC20 tokenContract = IERC20(token);
        require(
            tokenContract.balanceOf(address(this)) >= amount,
            "Insufficient token balance"
        );

        tokenContract.safeTransfer(to, amount);

        emit EmergencyWithdrawal(token, to, amount);
    }

    /**
     * @dev Gets the balance of a specific token in the contract
     * @param token Address of the token
     * @return Token balance
     */
    function getTokenBalance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    /**
     * @dev Gets dividend information by ID
     * @param dividendId ID of the dividend
     * @return Dividend information
     */
    function getDividendInfo(
        uint256 dividendId
    ) external view returns (DividendInfo memory) {
        return dividendHistory[dividendId];
    }

    /**
     * @dev Gets current fee configuration
     * @return feePercentage Current fee percentage in basis points
     * @return feeAddress Current fee address
     */
    function getFeeConfiguration() external view returns (uint256, address) {
        return (feePercentage, feeAddress);
    }

    // ===========================================
    // DISTRIBUTION APPROVAL SYSTEM
    // ===========================================

    /**
     * @dev Proposes a dividend distribution for approval
     * @param name Name of the distribution
     * @param token Address of the token to distribute
     * @param recipients Array of recipient addresses
     * @param amounts Array of amounts for each recipient
     * @param expiry Optional expiry timestamp (0 = use default)
     * @return distributionId ID of the created proposal
     */
    function proposeDistribution(
        string memory name,
        address token,
        address[] memory recipients,
        uint256[] memory amounts,
        uint256 expiry
    ) external returns (uint256 distributionId) {
        require(bytes(name).length > 0, "Distribution name required");
        require(token != address(0), "Invalid token address");
        require(recipients.length > 0, "Recipients required");
        require(recipients.length == amounts.length, "Arrays length mismatch");
        require(recipients.length <= maxBatchSize, "Too many recipients");

        // Check if caller has proposer role or is owner
        require(
            hasRole(DISTRIBUTION_PROPOSER_ROLE, msg.sender) || hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "Not authorized to propose distributions"
        );

        // Calculate total amount
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            require(amounts[i] > 0, "Amount must be greater than 0");
            require(recipients[i] != address(0), "Invalid recipient address");
            totalAmount += amounts[i];
        }

        // Check contract has sufficient balance
        require(
            IERC20(token).balanceOf(address(this)) >= totalAmount,
            "Insufficient token balance"
        );

        distributionId = distributionCounter++;

        // Set expiry: if per-call expiry is 0, use default; if default is 0, treat as no expiry
        uint256 finalExpiry;
        if (expiry == 0) {
            finalExpiry = (distributionExpiry == 0) ? 0 : block.timestamp + distributionExpiry;
        } else {
            finalExpiry = expiry;
        }

        distributionProposals[distributionId] = DistributionProposal({
            distributionId: distributionId,
            name: name,
            token: token,
            recipients: recipients,
            amounts: amounts,
            proposer: msg.sender,
            timestamp: block.timestamp,
            status: DistributionStatus.Pending,
            approver: address(0),
            actionTimestamp: 0,
            expiry: finalExpiry
        });

        // Add to pending list
        pendingDistributionIndex[distributionId] = pendingDistributionIds.length;
        pendingDistributionIds.push(distributionId);

        emit DistributionProposed(
            distributionId,
            msg.sender,
            name,
            token,
            totalAmount,
            recipients.length,
            block.timestamp
        );

        return distributionId;
    }

    /**
     * @dev Approves a pending distribution proposal
     * @param distributionId ID of the distribution to approve
     * @return dividendId ID of the executed dividend
     */
    function approveDistribution(
        uint256 distributionId
    ) external onlyRole(DIVIDEND_APPROVER_ROLE) returns (uint256 dividendId) {
        DistributionProposal storage proposal = distributionProposals[distributionId];
        
        require(proposal.distributionId == distributionId, "Distribution does not exist");
        require(proposal.status == DistributionStatus.Pending, "Distribution not pending");
        require(proposal.expiry == 0 || block.timestamp <= proposal.expiry, "Distribution expired");

        // Update proposal status
        proposal.status = DistributionStatus.Approved;
        proposal.approver = msg.sender;
        proposal.actionTimestamp = block.timestamp;

        // Remove from pending list
        _removeFromPendingDistributions(distributionId);

        emit DistributionApproved(distributionId, msg.sender, block.timestamp);

        // Execute the distribution
        dividendId = _executeDistribution(proposal);

        // Update status to executed
        proposal.status = DistributionStatus.Executed;

        emit DistributionExecuted(distributionId, dividendId, block.timestamp);

        return dividendId;
    }

    /**
     * @dev Rejects a pending distribution proposal
     * @param distributionId ID of the distribution to reject
     */
    function rejectDistribution(uint256 distributionId) external onlyRole(DIVIDEND_APPROVER_ROLE) {
        DistributionProposal storage proposal = distributionProposals[distributionId];
        
        require(proposal.distributionId == distributionId, "Distribution does not exist");
        require(proposal.status == DistributionStatus.Pending, "Distribution not pending");

        // Update proposal status
        proposal.status = DistributionStatus.Rejected;
        proposal.approver = msg.sender;
        proposal.actionTimestamp = block.timestamp;

        // Remove from pending list
        _removeFromPendingDistributions(distributionId);

        emit DistributionRejected(distributionId, msg.sender, block.timestamp);
    }

    /**
     * @dev Cancels a distribution proposal (only proposer or admin)
     * @param distributionId ID of the distribution to cancel
     */
    function cancelDistribution(uint256 distributionId) external {
        DistributionProposal storage proposal = distributionProposals[distributionId];
        
        require(proposal.distributionId == distributionId, "Distribution does not exist");
        require(proposal.status == DistributionStatus.Pending, "Distribution not pending");
        require(
            proposal.proposer == msg.sender || hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "Not authorized to cancel"
        );

        // Update proposal status
        proposal.status = DistributionStatus.Cancelled;
        proposal.approver = msg.sender;
        proposal.actionTimestamp = block.timestamp;

        // Remove from pending list
        _removeFromPendingDistributions(distributionId);

        emit DistributionCancelled(distributionId, msg.sender, block.timestamp);
    }

    /**
     * @dev Gets all pending distribution IDs
     * @return Array of pending distribution IDs
     */
    function getPendingDistributions() external view returns (uint256[] memory) {
        return pendingDistributionIds;
    }

    /**
     * @dev Gets detailed information about multiple distributions
     * @param distributionIds Array of distribution IDs to query
     * @return Array of DistributionProposal structs
     */
    function getDistributions(
        uint256[] calldata distributionIds
    ) external view returns (DistributionProposal[] memory) {
        DistributionProposal[] memory result = new DistributionProposal[](distributionIds.length);
        for (uint256 i = 0; i < distributionIds.length; i++) {
            result[i] = distributionProposals[distributionIds[i]];
        }
        return result;
    }

    /**
     * @dev Gets all pending distributions with full details
     * @return Array of pending DistributionProposal structs
     */
    function getAllPendingDistributions() external view returns (DistributionProposal[] memory) {
        DistributionProposal[] memory result = new DistributionProposal[](pendingDistributionIds.length);
        for (uint256 i = 0; i < pendingDistributionIds.length; i++) {
            result[i] = distributionProposals[pendingDistributionIds[i]];
        }
        return result;
    }

    /**
     * @dev Gets all cancelled distributions with full details
     * @return Array of cancelled DistributionProposal structs
     */
    function getAllCancelledDistributions() external view returns (DistributionProposal[] memory) {
        uint256 count;
        for (uint256 i = 0; i < distributionCounter; i++) {
            if (distributionProposals[i].status == DistributionStatus.Cancelled) {
                count++;
            }
        }
        DistributionProposal[] memory result = new DistributionProposal[](count);
        uint256 idx;
        for (uint256 i = 0; i < distributionCounter; i++) {
            if (distributionProposals[i].status == DistributionStatus.Cancelled) {
                result[idx++] = distributionProposals[i];
            }
        }
        return result;
    }

    /**
     * @dev Gets all rejected distributions with full details
     * @return Array of rejected DistributionProposal structs
     */
    function getAllRejectedDistributions() external view returns (DistributionProposal[] memory) {
        uint256 count;
        for (uint256 i = 0; i < distributionCounter; i++) {
            if (distributionProposals[i].status == DistributionStatus.Rejected) {
                count++;
            }
        }
        DistributionProposal[] memory result = new DistributionProposal[](count);
        uint256 idx;
        for (uint256 i = 0; i < distributionCounter; i++) {
            if (distributionProposals[i].status == DistributionStatus.Rejected) {
                result[idx++] = distributionProposals[i];
            }
        }
        return result;
    }

    /**
     * @dev Gets all completed (executed) distributions with full details
     * @return Array of completed DistributionProposal structs
     */
    function getAllCompletedDistributions() external view returns (DistributionProposal[] memory) {
        uint256 count;
        for (uint256 i = 0; i < distributionCounter; i++) {
            if (distributionProposals[i].status == DistributionStatus.Executed) {
                count++;
            }
        }
        DistributionProposal[] memory result = new DistributionProposal[](count);
        uint256 idx;
        for (uint256 i = 0; i < distributionCounter; i++) {
            if (distributionProposals[i].status == DistributionStatus.Executed) {
                result[idx++] = distributionProposals[i];
            }
        }
        return result;
    }

    /**
     * @dev Gets distribution count by status
     * @param status Status to filter by
     * @return count Number of distributions with the given status
     */
    function getDistributionCountByStatus(
        DistributionStatus status
    ) external view returns (uint256 count) {
        for (uint256 i = 0; i < distributionCounter; i++) {
            if (distributionProposals[i].status == status) {
                count++;
            }
        }
        return count;
    }

    /**
     * @dev Sets the default expiry time for distributions
     * @param newExpiry New expiry time in seconds (0 = no expiry)
     */
    function setDistributionExpiry(uint256 newExpiry) external onlyOwner {
        distributionExpiry = newExpiry;
    }

    /**
     * @dev Returns contract capabilities and configuration for frontend
     * @return isApprovalSystemEnabled Whether approval system is enabled
     * @return isProposalSystemEnabled Whether proposal system is enabled
     * @return currentMaxBatchSize Current max recipients per batch
     * @return currentDefaultExpiry Current default distribution expiry in seconds
     * @return currentFeePercentage Current fee percentage in basis points
     * @return currentFeeAddress Current fee recipient address
     * @return currentManagementFeeAddress Current management fee recipient address
     * @return functionsAvailable Available callable functions in frontend
     */
    function getContractCapabilities() external view returns (
        bool isApprovalSystemEnabled,
        bool isProposalSystemEnabled,
        uint256 currentMaxBatchSize,
        uint256 currentDefaultExpiry,
        uint256 currentFeePercentage,
        address currentFeeAddress,
        address currentManagementFeeAddress,
        string[] memory functionsAvailable
    ) {
        string[] memory functions = new string[](8);
        functions[0] = "distributeDividend";
        functions[1] = "proposeDistribution";
        functions[2] = "approveDistribution";
        functions[3] = "rejectDistribution";
        functions[4] = "cancelDistribution";
        functions[5] = "getPendingDistributions";
        functions[6] = "getAllPendingDistributions";
        functions[7] = "getDistributions";

        return (
            true,  // hasApprovalSystem
            true,  // hasProposalSystem
            maxBatchSize,
            distributionExpiry,
            feePercentage,
            feeAddress,
            managementFeeAddress,
            functions
        );
    }

    /**
     * @dev Internal function to execute a distribution
     * @param proposal The approved distribution proposal
     * @return dividendId ID of the created dividend
     */
    function _executeDistribution(
        DistributionProposal memory proposal
    ) private returns (uint256 dividendId) {
        // Execute the distribution logic directly (same as distributeDividend but internal)
        require(bytes(proposal.name).length > 0, "Dividend name required");
        require(proposal.token != address(0), "Invalid token address");
        require(proposal.recipients.length == proposal.amounts.length, "Arrays length mismatch");
        require(proposal.recipients.length > 0, "No recipients provided");

        // Calculate totals
        uint256 totalDividendAmount = 0;
        for (uint256 i = 0; i < proposal.amounts.length; i++) {
            totalDividendAmount += proposal.amounts[i];
        }
        uint256 feeAmount = calculateFee(totalDividendAmount);
        uint256 managementFeeAmount = (totalDividendAmount * MANAGEMENT_FEE_BPS) / 10000;
        uint256 netAmount = totalDividendAmount - feeAmount - managementFeeAmount;

        // Validate token balance
        IERC20 tokenContract = IERC20(proposal.token);
        require(
            tokenContract.balanceOf(address(this)) >= totalDividendAmount,
            "Insufficient token balance"
        );

        // Store dividend info
        dividendId = dividendCounter++;
        dividendHistory[dividendId] = DividendInfo({
            name: proposal.name,
            token: proposal.token,
            totalAmount: totalDividendAmount,
            feeAmount: feeAmount,
            netAmount: netAmount,
            recipientCount: proposal.recipients.length,
            timestamp: block.timestamp,
            completed: false
        });

        // Distribute in batches
        uint256 batchSize = maxBatchSize;
        uint256 totalBatches = (proposal.recipients.length + batchSize - 1) / batchSize;

        for (uint256 batchIndex = 0; batchIndex < totalBatches; batchIndex++) {
            uint256 startIndex = batchIndex * batchSize;
            uint256 endIndex = startIndex + batchSize;
            if (endIndex > proposal.recipients.length) {
                endIndex = proposal.recipients.length;
            }

            for (uint256 i = startIndex; i < endIndex; i++) {
                _handlePayout(proposal.token, proposal.recipients[i], proposal.amounts[i]);
            }

            emit BatchTransferCompleted(
                proposal.token,
                batchIndex,
                endIndex - startIndex,
                netAmount / proposal.recipients.length
            );
        }

        // Collect fees
        if (feeAmount > 0) {
            tokenContract.safeTransfer(feeAddress, feeAmount);
            emit FeeCollected(dividendId, proposal.token, feeAddress, feeAmount, feePercentage);
        }

        if (managementFeeAmount > 0) {
            tokenContract.safeTransfer(managementFeeAddress, managementFeeAmount);
            emit ManagementFeeCollected(
                dividendId,
                proposal.token,
                managementFeeAddress,
                managementFeeAmount,
                MANAGEMENT_FEE_BPS
            );
        }

        // Mark as completed
        dividendHistory[dividendId].completed = true;

        emit DividendDistributed(
            dividendId,
            proposal.token,
            proposal.name,
            totalDividendAmount,
            feeAmount,
            netAmount,
            proposal.recipients.length,
            block.timestamp
        );

        return dividendId;
    }

    /**
     * @dev Internal function to remove a distribution from the pending list
     * @param distributionId ID of the distribution to remove
     */
    function _removeFromPendingDistributions(uint256 distributionId) private {
        uint256 index = pendingDistributionIndex[distributionId];
        uint256 lastIndex = pendingDistributionIds.length - 1;
        
        if (index != lastIndex) {
            // Move the last element to the deleted spot
            uint256 lastDistributionId = pendingDistributionIds[lastIndex];
            pendingDistributionIds[index] = lastDistributionId;
            pendingDistributionIndex[lastDistributionId] = index;
        }
        
        // Remove the last element
        pendingDistributionIds.pop();
        delete pendingDistributionIndex[distributionId];
    }

    /**
     * @dev Required by UUPSUpgradeable
     */
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    /**
     * @dev One-time bootstrap to set up AccessControl roles. Only owner can call.
     *      Grants DEFAULT_ADMIN_ROLE to `admin` and assigns proposer/approver roles.
     *      Safe to call multiple times; repeated grants are no-ops.
     * @param admin Address to receive DEFAULT_ADMIN_ROLE
     * @param proposers Addresses to grant DISTRIBUTION_PROPOSER_ROLE
     * @param approvers Addresses to grant DIVIDEND_APPROVER_ROLE
     */
    function bootstrapRoles(
        address admin,
        address[] calldata proposers,
        address[] calldata approvers
    ) external onlyOwner {
        require(admin != address(0), "Invalid admin");
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        for (uint256 i = 0; i < proposers.length; i++) {
            if (proposers[i] != address(0)) {
                _grantRole(DISTRIBUTION_PROPOSER_ROLE, proposers[i]);
            }
        }
        for (uint256 j = 0; j < approvers.length; j++) {
            if (approvers[j] != address(0)) {
                _grantRole(DIVIDEND_APPROVER_ROLE, approvers[j]);
            }
        }
    }
}