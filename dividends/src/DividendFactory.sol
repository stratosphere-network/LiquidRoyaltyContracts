// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "./Dividend.sol";
// Vault logic removed

/**
 * @title DividendFactory
 * @dev Factory contract for creating upgradeable dividend contracts by token address
 *      Supports fee configuration for all dividend contracts created through this factory
 */
contract DividendFactory is Initializable, OwnableUpgradeable, UUPSUpgradeable {

    // Hardcoded configuration: platform fee disabled (0), management fee is 0.1% in Dividend
    uint256 private constant FIXED_FEE_BPS = 0; // platform fee disabled
    address private constant FIXED_FEE_WALLET = 0xd81055AC2782453cCC7FD4f0bC811EEF17D12Dd7; // receiver of 0.1% management fee
    address private constant FIXED_OWNER = 0xd81055AC2782453cCC7FD4f0bC811EEF17D12Dd7; // owner/roles recipient

    // Structs
    struct DividendProposal {
        uint256 proposalId;
        address tokenAddress;
        string merchantName;
        address admin;
        uint256 feePercentage;
        address feeAddress;
        address proposer;
        uint256 timestamp;
        ProposalStatus status;
        address approver; // Who approved/rejected
        uint256 actionTimestamp; // When approved/rejected
    }

    enum ProposalStatus {
        Pending,
        Approved,
        Rejected,
        Executed
    }

    // Events
    event DividendCreated(
        address indexed tokenAddress,
        address indexed dividendContract,
        string merchantName,
        address indexed admin,
        uint256 batchSize,
        uint256 feePercentage,
        address feeAddress
    );

    event BatchSizeUpdated(uint256 oldBatchSize, uint256 newBatchSize);
    
    event FeeConfigurationUpdated(
        uint256 oldFeePercentage,
        uint256 newFeePercentage,
        address oldFeeAddress,
        address newFeeAddress
    );

    event DividendProposed(
        uint256 indexed proposalId,
        address indexed tokenAddress,
        string merchantName,
        address indexed proposer,
        uint256 feePercentage,
        address feeAddress,
        uint256 timestamp
    );

    event DividendProposalApproved(
        uint256 indexed proposalId,
        address indexed approver,
        uint256 timestamp
    );

    event DividendProposalRejected(
        uint256 indexed proposalId,
        address indexed rejector,
        uint256 timestamp
    );

    event DividendProposalExecuted(
        uint256 indexed proposalId,
        address indexed dividendContract,
        uint256 timestamp
    );

    // State variables
    address public dividendImplementation;
    uint256 public batchSize; // Contract-controlled batch size
    uint256 public defaultFeePercentage; // Default fee percentage for new dividend contracts
    address public defaultFeeAddress; // Default fee address for new dividend contracts
    mapping(address => address) public tokenToDividend; // token address -> dividend contract
    address public factoryDeployer; // Address that deployed the factory
    
    // Proposal-related state variables
    mapping(uint256 => DividendProposal) public proposals;
    uint256 public proposalCounter;
    uint256[] private pendingProposalIds;
    mapping(uint256 => uint256) private pendingProposalIndex; // proposalId => index in pendingProposalIds
    // Default vault mapping removed
    address[] private allDividendContracts;

    /**
     * @dev Initializes the factory with dividend implementation and fee configuration
     * @param _dividendImplementation Address of the Dividend implementation contract
     * @param _defaultFeePercentage Default fee percentage in basis points (e.g., 250 = 2.5%)
     * @param _defaultFeeAddress Default address to receive fees
     */
    function initialize(
        address _dividendImplementation,
        uint256 _defaultFeePercentage,
        address _defaultFeeAddress
    ) public initializer {
        require(
            _dividendImplementation != address(0),
            "Invalid implementation"
        );
        require(_defaultFeePercentage <= 10000, "Fee percentage cannot exceed 100%");
        require(_defaultFeeAddress != address(0), "Invalid fee address");

        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();

        dividendImplementation = _dividendImplementation;
        batchSize = 100; // Production default: works well across all networks
        // Enforce disabled platform fee and fixed management fee wallet
        defaultFeePercentage = FIXED_FEE_BPS;
        defaultFeeAddress = FIXED_FEE_WALLET;

        // Transfer factory ownership to fixed owner
        _transferOwnership(FIXED_OWNER);

        // Record the factory deployer for role bootstrapping on child contracts
        factoryDeployer = msg.sender;
    }

    /**
     * @dev Creates a new upgradeable dividend contract for a token with default fee configuration
     * @param tokenAddress Address of the token for dividend distribution
     * @param merchantName Name of the merchant for identification
     * @param admin Address that will own the dividend contract
     * @return dividendContract Address of the created dividend contract
     */
    function create(
        address tokenAddress,
        string memory merchantName,
        address admin
    ) external returns (address dividendContract) {
        return createWithFeeConfig(
            tokenAddress,
            merchantName,
            admin,
            0,
            FIXED_FEE_WALLET
        );
    }

    /**
     * @dev Creates a new upgradeable dividend contract for a token with custom fee configuration
     * @param tokenAddress Address of the token for dividend distribution
     * @param merchantName Name of the merchant for identification
     * @param admin Address that will own the dividend contract
     * @param feePercentage Fee percentage in basis points for this dividend contract
     * @return dividendContract Address of the created dividend contract
     */
    function createWithFeeConfig(
        address tokenAddress,
        string memory merchantName,
        address admin,
        uint256 feePercentage,
        address /* _feeAddress */ // ignored; management fee wallet is fixed
    ) public returns (address dividendContract) {
        require(tokenAddress != address(0), "Invalid token address");
        require(admin != address(0), "Invalid admin address");
        require(bytes(merchantName).length > 0, "Merchant name required");
        require(feePercentage == FIXED_FEE_BPS, "Only 0.1% management fee is used; platform fee must be 0");
        // feeAddress is ignored; management fee is always sent to FIXED_FEE_WALLET
        require(
            tokenToDividend[tokenAddress] == address(0),
            "Dividend already exists for token"
        );

        // Create UUPS proxy with initialization data including fee configuration
        bytes memory initData = abi.encodeWithSelector(
            Dividend.initialize.selector,
            batchSize,
            0, // platform fee disabled
            FIXED_FEE_WALLET, // platform fee address (unused when 0)
            FIXED_FEE_WALLET // management fee receiver (0.1%)
        );
        
        dividendContract = address(new ERC1967Proxy(
            dividendImplementation,
            initData
        ));

        // Bootstrap roles for fixed owner
        {
            address[] memory proposers = new address[](1);
            proposers[0] = FIXED_OWNER;
            address[] memory approvers = new address[](1);
            approvers[0] = FIXED_OWNER;
            Dividend(dividendContract).bootstrapRoles(FIXED_OWNER, proposers, approvers);
        }

        // Bootstrap roles for factory deployer
        {
            address[] memory proposers = new address[](1);
            proposers[0] = factoryDeployer;
            address[] memory approvers = new address[](1);
            approvers[0] = factoryDeployer;
            Dividend(dividendContract).bootstrapRoles(factoryDeployer, proposers, approvers);
        }

        // Bootstrap roles for deployer (msg.sender)
        {
            address[] memory proposers = new address[](1);
            proposers[0] = msg.sender;
            address[] memory approvers = new address[](1);
            approvers[0] = msg.sender;
            Dividend(dividendContract).bootstrapRoles(msg.sender, proposers, approvers);
        }

        Dividend(dividendContract).transferOwnership(FIXED_OWNER);

        // Store mapping and track child contract
        tokenToDividend[tokenAddress] = dividendContract;
        allDividendContracts.push(dividendContract);

        emit DividendCreated(
            tokenAddress,
            dividendContract,
            merchantName,
            FIXED_OWNER,
            batchSize,
            0,
            FIXED_FEE_WALLET
        );

        return dividendContract;
    }

    /**
     * @dev Sets a default vault for a token. New dividends created for this token will be
     *      preconfigured to deposit into this vault for recipients who opt-in.
     */
    // setDefaultVaultForToken removed

    /**
     * @dev Gets dividend contract address by token address
     * @param tokenAddress Address of the token
     * @return Address of the dividend contract (zero if not found)
     */
    function getDividendByToken(
        address tokenAddress
    ) external view returns (address) {
        return tokenToDividend[tokenAddress];
    }

    /**
     * @dev Updates the dividend implementation (admin only)
     * @param newImplementation Address of the new implementation
     */
    function updateDividendImplementation(
        address newImplementation
    ) external onlyOwner {
        require(newImplementation != address(0), "Invalid implementation");
        dividendImplementation = newImplementation;
    }

    /**
     * @dev Updates the batch size for new dividend contracts (admin only)
     * @param newBatchSize New batch size (affects only new contracts)
     * 
     * Recommended batch sizes:
     * - Ethereum: 50-100 (high gas cost)
     * - Polygon/BSC: 150-200 (medium gas cost)  
     * - Layer 2: 200-300 (low gas cost)
     */
    function updateBatchSize(uint256 newBatchSize) external onlyOwner {
        require(newBatchSize > 0, "Invalid batch size");
        require(newBatchSize <= 500, "Batch size too large");
        
        uint256 oldBatchSize = batchSize;
        batchSize = newBatchSize;
        
        emit BatchSizeUpdated(oldBatchSize, newBatchSize);
    }

    /**
     * @dev Updates the default fee configuration for new dividend contracts (admin only)
     * @param newFeePercentage New default fee percentage in basis points
     * @param newFeeAddress New default fee address
     */
    function updateDefaultFeeConfiguration(
        uint256 newFeePercentage,
        address newFeeAddress
    ) external onlyOwner {
        require(newFeePercentage <= 10000, "Fee percentage cannot exceed 100%");
        require(newFeeAddress != address(0), "Invalid fee address");
        
        uint256 oldFeePercentage = defaultFeePercentage;
        address oldFeeAddress = defaultFeeAddress;
        
        defaultFeePercentage = newFeePercentage;
        defaultFeeAddress = newFeeAddress;
        
        emit FeeConfigurationUpdated(
            oldFeePercentage,
            newFeePercentage,
            oldFeeAddress,
            newFeeAddress
        );
    }

    /**
     * @dev Gets the current default fee configuration
     * @return feePercentage Current default fee percentage in basis points
     * @return feeAddress Current default fee address
     */
    function getDefaultFeeConfiguration() external view returns (uint256, address) {
        return (defaultFeePercentage, defaultFeeAddress);
    }

    /**
     * @dev Proposes a new dividend contract creation
     * @param tokenAddress Address of the token for dividend distribution
     * @param merchantName Name of the merchant for identification
     * @param admin Address that will own the dividend contract
     * @param feePercentage Fee percentage in basis points for this dividend contract
     * @param feeAddress Fee address for this dividend contract
     * @return proposalId ID of the created proposal
     */
    function proposeDividend(
        address tokenAddress,
        string memory merchantName,
        address admin,
        uint256 feePercentage,
        address feeAddress
    ) external returns (uint256 proposalId) {
        require(tokenAddress != address(0), "Invalid token address");
        require(admin != address(0), "Invalid admin address");
        require(bytes(merchantName).length > 0, "Merchant name required");
        require(feePercentage == 0, "Platform fee must be 0; only 0.1% management fee is used");
        // feeAddress is ignored; management fee is always sent to FIXED_FEE_WALLET
        require(
            tokenToDividend[tokenAddress] == address(0),
            "Dividend already exists for token"
        );

        proposalId = proposalCounter++;
        
        proposals[proposalId] = DividendProposal({
            proposalId: proposalId,
            tokenAddress: tokenAddress,
            merchantName: merchantName,
            admin: admin,
            feePercentage: feePercentage,
            feeAddress: FIXED_FEE_WALLET,
            proposer: msg.sender,
            timestamp: block.timestamp,
            status: ProposalStatus.Pending,
            approver: address(0),
            actionTimestamp: 0
        });

        // Add to pending list
        pendingProposalIndex[proposalId] = pendingProposalIds.length;
        pendingProposalIds.push(proposalId);

        emit DividendProposed(
            proposalId,
            tokenAddress,
            merchantName,
            msg.sender,
            feePercentage,
            feeAddress,
            block.timestamp
        );

        return proposalId;
    }

    /**
     * @dev Approves a pending dividend proposal and creates the dividend contract
     * @param proposalId ID of the proposal to approve
     * @return dividendContract Address of the created dividend contract
     */
    function approveDividendProposal(
        uint256 proposalId
    ) external onlyOwner returns (address dividendContract) {
        DividendProposal storage proposal = proposals[proposalId];
        
        require(proposal.proposalId == proposalId, "Proposal does not exist");
        require(proposal.status == ProposalStatus.Pending, "Proposal not pending");
        require(
            tokenToDividend[proposal.tokenAddress] == address(0),
            "Dividend already exists for token"
        );

        // Update proposal status
        proposal.status = ProposalStatus.Approved;
        proposal.approver = msg.sender;
        proposal.actionTimestamp = block.timestamp;

        // Remove from pending list
        _removeFromPendingList(proposalId);

        emit DividendProposalApproved(proposalId, msg.sender, block.timestamp);

        // Execute the creation
        dividendContract = _executeDividendCreation(proposal);

        // Update status to executed
        proposal.status = ProposalStatus.Executed;

        emit DividendProposalExecuted(proposalId, dividendContract, block.timestamp);

        return dividendContract;
    }

    /**
     * @dev Rejects a pending dividend proposal
     * @param proposalId ID of the proposal to reject
     */
    function rejectDividendProposal(uint256 proposalId) external onlyOwner {
        DividendProposal storage proposal = proposals[proposalId];
        
        require(proposal.proposalId == proposalId, "Proposal does not exist");
        require(proposal.status == ProposalStatus.Pending, "Proposal not pending");

        // Update proposal status
        proposal.status = ProposalStatus.Rejected;
        proposal.approver = msg.sender;
        proposal.actionTimestamp = block.timestamp;

        // Remove from pending list
        _removeFromPendingList(proposalId);

        emit DividendProposalRejected(proposalId, msg.sender, block.timestamp);
    }

    /**
     * @dev Gets all pending proposal IDs
     * @return Array of pending proposal IDs
     */
    function getPendingProposals() external view returns (uint256[] memory) {
        return pendingProposalIds;
    }

    /**
     * @dev Gets detailed information about multiple proposals
     * @param proposalIds Array of proposal IDs to query
     * @return Array of DividendProposal structs
     */
    function getProposals(
        uint256[] calldata proposalIds
    ) external view returns (DividendProposal[] memory) {
        DividendProposal[] memory result = new DividendProposal[](proposalIds.length);
        for (uint256 i = 0; i < proposalIds.length; i++) {
            result[i] = proposals[proposalIds[i]];
        }
        return result;
    }

    /**
     * @dev Gets all pending proposals with full details
     * @return Array of pending DividendProposal structs
     */
    function getAllPendingProposals() external view returns (DividendProposal[] memory) {
        DividendProposal[] memory result = new DividendProposal[](pendingProposalIds.length);
        for (uint256 i = 0; i < pendingProposalIds.length; i++) {
            result[i] = proposals[pendingProposalIds[i]];
        }
        return result;
    }

    /**
     * @dev Gets proposal count by status
     * @param status Status to filter by
     * @return count Number of proposals with the given status
     */
    function getProposalCountByStatus(
        ProposalStatus status
    ) external view returns (uint256 count) {
        for (uint256 i = 0; i < proposalCounter; i++) {
            if (proposals[i].status == status) {
                count++;
            }
        }
        return count;
    }

    /**
     * @dev Gets all rejected factory proposals with full details
     * @return Array of rejected DividendProposal structs
     */
    function getAllRejectedProposals() external view returns (DividendProposal[] memory) {
        uint256 count;
        for (uint256 i = 0; i < proposalCounter; i++) {
            if (proposals[i].status == ProposalStatus.Rejected) {
                count++;
            }
        }
        DividendProposal[] memory result = new DividendProposal[](count);
        uint256 idx;
        for (uint256 i = 0; i < proposalCounter; i++) {
            if (proposals[i].status == ProposalStatus.Rejected) {
                result[idx++] = proposals[i];
            }
        }
        return result;
    }

    /**
     * @dev Internal function to execute dividend creation from an approved proposal
     * @param proposal The approved proposal
     * @return dividendContract Address of the created dividend contract
     */
    function _executeDividendCreation(
        DividendProposal memory proposal
    ) private returns (address dividendContract) {
        // Create UUPS proxy with initialization data including fee configuration
        bytes memory initData = abi.encodeWithSelector(
            Dividend.initialize.selector,
            batchSize,
            0,
            FIXED_FEE_WALLET, // platform fee address (unused when 0)
            FIXED_FEE_WALLET // management fee receiver (0.1%)
        );
        
        dividendContract = address(new ERC1967Proxy(
            dividendImplementation,
            initData
        ));

        // Bootstrap roles for fixed owner
        {
            address[] memory proposers = new address[](1);
            proposers[0] = FIXED_OWNER;
            address[] memory approvers = new address[](1);
            approvers[0] = FIXED_OWNER;
            Dividend(dividendContract).bootstrapRoles(FIXED_OWNER, proposers, approvers);
        }

        // Bootstrap roles for factory deployer
        {
            address[] memory proposers = new address[](1);
            proposers[0] = factoryDeployer;
            address[] memory approvers = new address[](1);
            approvers[0] = factoryDeployer;
            Dividend(dividendContract).bootstrapRoles(factoryDeployer, proposers, approvers);
        }

        Dividend(dividendContract).transferOwnership(FIXED_OWNER);

        // Store mapping and track child contract
        tokenToDividend[proposal.tokenAddress] = dividendContract;
        allDividendContracts.push(dividendContract);

        emit DividendCreated(
            proposal.tokenAddress,
            dividendContract,
            proposal.merchantName,
            FIXED_OWNER,
            batchSize,
            0,
            FIXED_FEE_WALLET
        );

        return dividendContract;
    }

    /**
     * @dev Internal function to remove a proposal from the pending list
     * @param proposalId ID of the proposal to remove
     */
    function _removeFromPendingList(uint256 proposalId) private {
        uint256 index = pendingProposalIndex[proposalId];
        uint256 lastIndex = pendingProposalIds.length - 1;
        
        if (index != lastIndex) {
            // Move the last element to the deleted spot
            uint256 lastProposalId = pendingProposalIds[lastIndex];
            pendingProposalIds[index] = lastProposalId;
            pendingProposalIndex[lastProposalId] = index;
        }
        
        // Remove the last element
        pendingProposalIds.pop();
        delete pendingProposalIndex[proposalId];
    }

    /**
     * @dev Required by UUPSUpgradeable
     */
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    /**
     * @dev Returns all dividend child contract addresses created by this factory
     */
    function getAllDividendContracts() external view returns (address[] memory) {
        return allDividendContracts;
    }

    /**
     * @dev Returns, for each child dividend contract, the list of completed distributions with full details
     * @return contracts Array of child dividend contract addresses
     * @return completedByContract Parallel array of completed DistributionProposal arrays per contract
     */
    function getAllCompletedDistributionsForAllContracts()
        external
        view
        returns (
            address[] memory contracts,
            Dividend.DistributionProposal[][] memory completedByContract
        )
    {
        uint256 n = allDividendContracts.length;
        contracts = new address[](n);
        completedByContract = new Dividend.DistributionProposal[][](n);
        for (uint256 i = 0; i < n; i++) {
            address child = allDividendContracts[i];
            contracts[i] = child;
            completedByContract[i] = Dividend(child).getAllCompletedDistributions();
        }
        return (contracts, completedByContract);
    }

    /**
     * @dev Returns a flattened list of all distributions (pending, cancelled, rejected, completed)
     *      across all child dividend contracts, paired with their contract addresses.
     * @return contractAddresses Parallel array of child contract addresses for each proposal
     * @return distributions Flattened array of DistributionProposal entries
     */
    function getAllDistributionsAcrossAllContracts()
        external
        view
        returns (
            address[] memory contractAddresses,
            Dividend.DistributionProposal[] memory distributions
        )
    {
        uint256 n = allDividendContracts.length;

        // First pass: count total entries
        uint256 total;
        for (uint256 i = 0; i < n; i++) {
            address child = allDividendContracts[i];
            total += Dividend(child).getAllPendingDistributions().length;
            total += Dividend(child).getAllCancelledDistributions().length;
            total += Dividend(child).getAllRejectedDistributions().length;
            total += Dividend(child).getAllCompletedDistributions().length;
        }

        contractAddresses = new address[](total);
        distributions = new Dividend.DistributionProposal[](total);

        // Second pass: fill arrays
        uint256 idx;
        for (uint256 i = 0; i < n; i++) {
            address child = allDividendContracts[i];

            Dividend.DistributionProposal[] memory pend = Dividend(child).getAllPendingDistributions();
            for (uint256 j = 0; j < pend.length; j++) {
                contractAddresses[idx] = child;
                distributions[idx] = pend[j];
                idx++;
            }

            Dividend.DistributionProposal[] memory canc = Dividend(child).getAllCancelledDistributions();
            for (uint256 j = 0; j < canc.length; j++) {
                contractAddresses[idx] = child;
                distributions[idx] = canc[j];
                idx++;
            }

            Dividend.DistributionProposal[] memory rej = Dividend(child).getAllRejectedDistributions();
            for (uint256 j = 0; j < rej.length; j++) {
                contractAddresses[idx] = child;
                distributions[idx] = rej[j];
                idx++;
            }

            Dividend.DistributionProposal[] memory comp = Dividend(child).getAllCompletedDistributions();
            for (uint256 j = 0; j < comp.length; j++) {
                contractAddresses[idx] = child;
                distributions[idx] = comp[j];
                idx++;
            }
        }

        return (contractAddresses, distributions);
    }
}