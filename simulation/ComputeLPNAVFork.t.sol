// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

/// @dev Minimal interfaces for live COMPUTE.r vault fork simulation (Berachain mainnet).
interface IERC20Minimal {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function approve(address, uint256) external returns (bool);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
}

interface IKodiakIsland {
    function getUnderlyingBalances() external view returns (uint112 token0Amount, uint112 token1Amount);
    function totalSupply() external view returns (uint256);
}

interface IKodiakVaultHook {
    function island() external view returns (IKodiakIsland);
    function getIslandLPBalance() external view returns (uint256);
}

interface IVault {
    function vaultValue() external view returns (uint256);
    function totalAssets() external view returns (uint256);
    function kodiakHook() external view returns (IKodiakVaultHook);
    function admin() external view returns (address);
    function liquidityManager() external view returns (address);
    function priceFeedManager() external view returns (address);
    function isSeeder(address) external view returns (bool);
    function withdrawLPTokens(address lpToken, address lp, uint256 amount) external;
    function transferToLMV(address token, uint256 amount) external;
    function seedVault(address lpToken, uint256 amount, uint256 lpPrice) external;
    function executeVaultValueAction(uint8 action, int256 value) external;
}

contract ComputeLPNAVForkTest is Test {
    address constant SENIOR = 0xeb04926d24b9526D847498153C88d80296F1bb73;
    address constant JUNIOR = 0x3499a7FFB37Dbd4d0d94c203614C093314FD937f;
    address constant ISLAND = 0x40E8Fa74792274d9d9A328D41324E9d5199C0A16;
    address constant USDE = 0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34;
    address constant COMPUTE = 0xB8CD0b8E056A91c00FD388EdDb37E6E445844B21;

    uint256 constant TARGET_USD = 1_000_000e18;
    string constant RPC = "https://rpc.berachain.com";

    struct Snapshot {
        string label;
        uint256 seniorTotalAssets;
        uint256 juniorTotalAssets;
        uint256 seniorSlot3Value;
        uint256 juniorSlot3Value;
        uint256 seniorIslandOnVault;
        uint256 juniorIslandOnVault;
        uint256 seniorIslandOnOperator;
        uint256 juniorIslandOnOperator;
        uint256 seniorIslandOnHook;
        uint256 juniorIslandOnHook;
        uint256 impliedSeniorUsd;
        uint256 impliedJuniorUsd;
        string notes;
    }

    Snapshot[] public snapshots;

    function setUp() public {
        vm.createSelectFork(RPC);
    }


    function testDiscoverTransferToLMVCaller() public {
        vm.createSelectFork(RPC);
        uint256 amt = 1e18;
        deal(ISLAND, SENIOR, amt);
        address[] memory callers = new address[](6);
        callers[0] = address(uint160(uint256(vm.load(SENIOR, bytes32(uint256(2))))));
        callers[1] = address(uint160(uint256(vm.load(SENIOR, bytes32(uint256(1))))));
        callers[2] = 0xC465a6368D3708f6B738Cc46b9A1Ac650e1dE010;
        callers[3] = 0xE532DFede91f04B12a73d3d2Acd361424F41f76B;
        callers[4] = 0x6fa2149E69DbCBDCf6F16F755E08c10E53c40605;
        callers[5] = 0x246f89F3b451133bB9a84c3f0871C9198b90AA04;
        for (uint256 i = 0; i < callers.length; i++) {
            vm.startPrank(callers[i]);
            try IVault(SENIOR).transferToLMV(ISLAND, amt) {
                console2.log("transferToLMV succeeded caller", callers[i]);
            } catch {
                console2.log("transferToLMV failed caller", callers[i]);
            }
            vm.stopPrank();
        }
    }

    function testTotalAssetsMarksOperatorWallet() public {
        vm.createSelectFork(RPC);
        address op = address(uint160(uint256(vm.load(SENIOR, bytes32(uint256(2))))));
        uint256 lp = 1e20;
        uint256 base = IVault(SENIOR).totalAssets();
        console2.log("baseline totalAssets", base);
        deal(ISLAND, SENIOR, lp);
        uint256 navVaultOnly = IVault(SENIOR).totalAssets();
        console2.log("after vault-only island deal totalAssets", navVaultOnly);
        deal(ISLAND, op, lp);
        uint256 navOp = IVault(SENIOR).totalAssets();
        console2.log("after operator island deal totalAssets", navOp);
        console2.log("stored slot3 vaultValue", _storedVaultValue(SENIOR));
    }

    function testComputeLPSeedAndLMVFlow() public {
        uint256 forkBlock = block.number;
        console2.log("Fork block:", forkBlock);

        (uint256 lpPerUsd, uint256 usdPerLp, uint112 usdeInPool, uint256 lpSupply) = _islandPricing();
        uint256 lpFor1M = (TARGET_USD * lpSupply) / uint256(usdeInPool); // USDe token0 reserve mark

        console2.log("Island LP supply:", lpSupply);
        console2.log("USDe in pool (token1 side):", uint256(usdeInPool));
        console2.log("Implied USD per 1 LP (18 dec):", usdPerLp);
        console2.log("LP amount for ~$1M (raw):", lpFor1M);

        _record("0-baseline", "Before any LP transfer");

        address lpWhale = _findLpWhale(lpFor1M * 2 + 1e18);
        console2.log("LP whale:", lpWhale);

        vm.startPrank(lpWhale);
        IERC20Minimal(ISLAND).transfer(SENIOR, lpFor1M);
        IERC20Minimal(ISLAND).transfer(JUNIOR, lpFor1M);
        vm.stopPrank();

        _record("1-after-erc20-to-vault", "Island LP sitting on vault contract balances only");

        address seniorLm = _operatorWallet(SENIOR);
        address juniorLm = _operatorWallet(JUNIOR);
        address seniorHook = _kodiakHook(SENIOR);
        address juniorHook = _kodiakHook(JUNIOR);
        console2.log("Senior operator/LMV wallet (storage slot 2):", seniorLm);
        console2.log("Junior operator/LMV wallet (storage slot 2):", juniorLm);
        console2.log("Senior hook (if any):", seniorHook);
        console2.log("Junior hook (if any):", juniorHook);

        string memory lmvNotes = "";
        bool seniorOk = _tryTransferToLMV(SENIOR, seniorLm, seniorHook, lpFor1M);
        lmvNotes = string.concat(lmvNotes, seniorOk ? "Senior LMV OK; " : "Senior LMV reverted (simulated move); ");
        bool juniorOk = _tryTransferToLMV(JUNIOR, juniorLm, juniorHook, lpFor1M);
        lmvNotes = string.concat(lmvNotes, juniorOk ? "Junior LMV OK; " : "Junior LMV reverted (simulated move); ");

        _record("2-after-LMV-transfer", lmvNotes);

        // If on-chain transferToLMV is ACL-gated, mimic its effect: Island LP leaves vault body → operator wallet (slot 2).
        if (!seniorOk) {
            vm.prank(SENIOR);
            IERC20Minimal(ISLAND).transfer(seniorLm, lpFor1M);
        }
        if (!juniorOk) {
            vm.prank(JUNIOR);
            IERC20Minimal(ISLAND).transfer(juniorLm, lpFor1M);
        }
        if (!seniorOk || !juniorOk) {
            _record("2b-after-simulated-LMV-routing", "Manual vault->operator transfer (effect of transferToLMV)");
        }

        address seniorPf = _tryPriceFeed(SENIOR);
        if (seniorPf != address(0)) {
            vm.startPrank(seniorPf);
            try IVault(SENIOR).executeVaultValueAction(1, int256(TARGET_USD)) {
                _record("3-senior-manual-set-value", "priceFeed SET (=1) to 1M USD on Senior only (probe)");
            } catch {
                snapshots[snapshots.length - 1].notes = string.concat(snapshots[snapshots.length - 1].notes, " | SET failed");
            }
            vm.stopPrank();
        }

        assertTrue(true);
    }

    /// @dev ContractTester layout: slot 2 holds the operator / LMV wallet used by totalAssets().
    function _tryTransferToLMV(address vault, address operator, address hook, uint256 amount) internal returns (bool) {
        vm.startPrank(operator);
        try IVault(vault).transferToLMV(ISLAND, amount) {
            vm.stopPrank();
            return true;
        } catch {
            vm.stopPrank();
            if (hook != address(0)) {
                vm.startPrank(operator);
                try IVault(vault).withdrawLPTokens(ISLAND, hook, amount) {
                    vm.stopPrank();
                    return true;
                } catch {
                    vm.stopPrank();
                }
            }
        }
        return false;
    }

    function _operatorWallet(address vault) internal view returns (address) {
        return address(uint160(uint256(vm.load(vault, bytes32(uint256(2))))));
    }

    function _kodiakHook(address vault) internal view returns (address) {
        try IVault(vault).kodiakHook() returns (IKodiakVaultHook h) {
            return address(h);
        } catch {
            return address(0);
        }
    }

    function _storedVaultValue(address vault) internal view returns (uint256) {
        return uint256(vm.load(vault, bytes32(uint256(3))));
    }

    function _tryPriceFeed(address vault) internal view returns (address) {
        try IVault(vault).priceFeedManager() returns (address pf) {
            return pf;
        } catch {
            return address(0);
        }
    }

    function _findLpWhale(uint256 minBal) internal returns (address) {
        // Known Kodiak / vault LPs on Berachain (verified balances at fork time)
        address[] memory candidates = new address[](8);
        candidates[0] = 0x246f89F3b451133bB9a84c3f0871C9198b90AA04; // admin-ish hot wallet from storage
        candidates[1] = 0x23FD5F6e2B07970c9B00D1da8E85c201711B7b74; // treasury
        candidates[2] = 0xB497A2Dd112eb405928775211aC7BEc5b9071c91; // ALAR COMPUTE
        candidates[3] = 0x6fa2149E69DbCBDCf6F16F755E08c10E53c40605; // prod admin from scripts
        candidates[4] = 0x49298F4314eb127041b814A2616c25687Db6b650; // legacy senior
        candidates[5] = 0x7754272c866892CaD4a414C76f060645bDc27203; // legacy reserve
        candidates[6] = 0x3a0A97DcA5e6CaCC258490d5ece453412f8E1883; // legacy junior
        candidates[7] = 0x0000000000000000000000000000000000000001;

        for (uint256 i = 0; i < candidates.length - 1; i++) {
            if (IERC20Minimal(ISLAND).balanceOf(candidates[i]) >= minBal) {
                return candidates[i];
            }
        }
        // deal fallback (ERC20 without balance slot restrictions on fork)
        address funded = address(0xBEEF);
        deal(ISLAND, funded, minBal);
        return funded;
    }

    function _islandPricing()
        internal
        view
        returns (uint256 lpPerUsd, uint256 usdPerLp, uint112 usdeInPool, uint256 lpSupply)
    {
        lpSupply = IKodiakIsland(ISLAND).totalSupply();
        (uint256 usdeInPoolRaw,) = IKodiakIsland(ISLAND).getUnderlyingBalances(); // token0 = USDe
        usdeInPool = uint112(usdeInPoolRaw);
        require(usdeInPool > 0, "USDe reserve is zero");
        lpPerUsd = (lpSupply * 1e18) / usdeInPoolRaw;
        usdPerLp = (usdeInPoolRaw * 1e18) / lpSupply;
    }

    function _record(string memory label, string memory notes) internal {
        Snapshot memory s;
        s.label = label;
        s.seniorTotalAssets = IVault(SENIOR).totalAssets();
        s.juniorTotalAssets = IVault(JUNIOR).totalAssets();
        s.seniorSlot3Value = _storedVaultValue(SENIOR);
        s.juniorSlot3Value = _storedVaultValue(JUNIOR);
        s.seniorIslandOnVault = IERC20Minimal(ISLAND).balanceOf(SENIOR);
        s.juniorIslandOnVault = IERC20Minimal(ISLAND).balanceOf(JUNIOR);
        s.seniorIslandOnOperator = IERC20Minimal(ISLAND).balanceOf(_operatorWallet(SENIOR));
        s.juniorIslandOnOperator = IERC20Minimal(ISLAND).balanceOf(_operatorWallet(JUNIOR));

        address sh = address(0);
        address jh = address(0);
        try IVault(SENIOR).kodiakHook() returns (IKodiakVaultHook h) {
            sh = address(h);
            s.seniorIslandOnHook = h.getIslandLPBalance();
        } catch {}
        try IVault(JUNIOR).kodiakHook() returns (IKodiakVaultHook h) {
            jh = address(h);
            s.juniorIslandOnHook = h.getIslandLPBalance();
        } catch {}

        (uint256 lpSupply, uint112 usdeInPool) = _islandPricingCompact();
        s.impliedSeniorUsd = lpSupply == 0 ? 0 : (s.seniorIslandOnHook * uint256(usdeInPool)) / lpSupply;
        s.impliedJuniorUsd = lpSupply == 0 ? 0 : (s.juniorIslandOnHook * uint256(usdeInPool)) / lpSupply;
        s.notes = notes;
        snapshots.push(s);

        console2.log("---", label);
        console2.log("  Senior totalAssets / slot3:", s.seniorTotalAssets, s.seniorSlot3Value);
        console2.log("  Junior totalAssets / slot3:", s.juniorTotalAssets, s.juniorSlot3Value);
        console2.log("  Senior island vault/operator/hook:", s.seniorIslandOnVault, s.seniorIslandOnOperator, s.seniorIslandOnHook);
        console2.log("  Junior island vault/operator/hook:", s.juniorIslandOnVault, s.juniorIslandOnOperator, s.juniorIslandOnHook);
        console2.log("  Implied hook USD senior/junior:", s.impliedSeniorUsd, s.impliedJuniorUsd);
    }

    function _islandPricingCompact() internal view returns (uint256 lpSupply, uint112 usdeInPool) {
        lpSupply = IKodiakIsland(ISLAND).totalSupply();
        (uint256 usde0,) = IKodiakIsland(ISLAND).getUnderlyingBalances();
        usdeInPool = uint112(usde0);
    }

    function _safeVaultValue(address vault) internal view returns (uint256 v) {
        try IVault(vault).vaultValue() returns (uint256 x) {
            return x;
        } catch {}
        try IVault(vault).totalAssets() returns (uint256 y) {
            return y;
        } catch {}
        return _storedVaultValue(vault);
    }

}
