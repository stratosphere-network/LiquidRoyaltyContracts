// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";

/// @notice Writes Safe Transaction Builder JSON batches for post-deploy CCIP wiring (no on-chain execution).
/// @dev Execution order (see docs/meta_senior_path1_upgrade.md):
///      1) Moss: Path1 impl + both pools.
///      2) Bera Safe: upgradeToAndCall(impl, initializePath1) BEFORE grantRole on Meta Senior.
///      3) Both Safes: these batches (registerAccessControlDefaultAdmin; pool acceptOwnership; grantRole to pool; TAR acceptAdminRole + setPool).
///      Optional: owner setRateLimitConfig later; no applyChainUpdates when factory wired remotes at deploy.
contract GenerateSnrUsdCcipSafeBatches is Script {
    address internal constant BERA_TAR = 0x0944C3Fb1dB7D165336569221995B31cBE6c8A55;
    address internal constant BERA_REGISTRY_MODULE = 0x160603D7C0Ac00409276bf6707430712Caf5b555;
    address internal constant BERA_META_TOKEN = 0xC38421E5577250EBa177Bc5bC832E747bea13Ee0;

    address internal constant BASE_TAR = 0x6f6C373d09C07425BaAE72317863d7F6bb731e37;
    address internal constant BASE_REGISTRY_MODULE = 0xAFEd606Bd2CAb6983fC6F10167c98aaC2173D77f;
    address internal constant BASE_SNR_TOKEN = 0xdB3A54CBC468e8D99d7522579174E0733D548507;

    bytes32 internal constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 internal constant BURNER_ROLE = keccak256("BURNER_ROLE");

    function run() external {
        address beraPool = vm.envAddress("BERA_POOL_ADDRESS");
        address basePool = vm.envAddress("BASE_POOL_ADDRESS");
        string memory outDir = "script/output/safe-batches";
        vm.createDir(outDir, true);

        string memory bera = _berachainBatch(beraPool);
        string memory base = _baseBatch(basePool);
        vm.writeFile(string.concat(outDir, "/berachain-snrusd-ccip.json"), bera);
        vm.writeFile(string.concat(outDir, "/base-snrusd-ccip.json"), base);

        console2.log("Wrote", outDir);
    }

    function _berachainBatch(address pool) internal view returns (string memory) {
        return string.concat(
            '{"version":"1.0","chainId":"80094","meta":{"name":"Berachain snrUSD CCIP"},"transactions":[',
            _tx(pool, abi.encodeWithSignature("acceptOwnership()")),
            ",",
            _tx(BERA_META_TOKEN, abi.encodeWithSignature("grantRole(bytes32,address)", MINTER_ROLE, pool)),
            ",",
            _tx(BERA_META_TOKEN, abi.encodeWithSignature("grantRole(bytes32,address)", BURNER_ROLE, pool)),
            ",",
            _tx(BERA_REGISTRY_MODULE, abi.encodeWithSignature("registerAccessControlDefaultAdmin(address)", BERA_META_TOKEN)),
            ",",
            _tx(BERA_TAR, abi.encodeWithSignature("acceptAdminRole(address)", BERA_META_TOKEN)),
            ",",
            _tx(BERA_TAR, abi.encodeWithSignature("setPool(address,address)", BERA_META_TOKEN, pool)),
            "]}"
        );
    }

    function _baseBatch(address pool) internal view returns (string memory) {
        return string.concat(
            '{"version":"1.0","chainId":"8453","meta":{"name":"Base snrUSD CCIP"},"transactions":[',
            _tx(pool, abi.encodeWithSignature("acceptOwnership()")),
            ",",
            _tx(BASE_SNR_TOKEN, abi.encodeWithSignature("grantRole(bytes32,address)", MINTER_ROLE, pool)),
            ",",
            _tx(BASE_SNR_TOKEN, abi.encodeWithSignature("grantRole(bytes32,address)", BURNER_ROLE, pool)),
            ",",
            _tx(BASE_REGISTRY_MODULE, abi.encodeWithSignature("registerAccessControlDefaultAdmin(address)", BASE_SNR_TOKEN)),
            ",",
            _tx(BASE_TAR, abi.encodeWithSignature("acceptAdminRole(address)", BASE_SNR_TOKEN)),
            ",",
            _tx(BASE_TAR, abi.encodeWithSignature("setPool(address,address)", BASE_SNR_TOKEN, pool)),
            "]}"
        );
    }

    function _tx(address to, bytes memory data) internal pure returns (string memory) {
        return string.concat('{"to":"', _addr(to), '","value":"0","data":"', _hex(data), '"}');
    }


    function _addr(address a) private pure returns (string memory) {
        return string.concat("0x", _toHex(uint256(uint160(a)), 20));
    }

    function _hex(bytes memory data) private pure returns (string memory) {
        return string.concat("0x", _toHexBytes(data));
    }

    function _toHexBytes(bytes memory data) private pure returns (string memory) {
        bytes memory out = new bytes(2 * data.length);
        for (uint256 i = 0; i < data.length; i++) {
            out[2 * i] = _HEX[uint8(data[i]) >> 4];
            out[2 * i + 1] = _HEX[uint8(data[i]) & 0x0f];
        }
        return string(out);
    }

    function _toHex(uint256 value, uint256 len) private pure returns (string memory) {
        bytes memory buffer = new bytes(2 * len);
        for (uint256 i = 2 * len; i > 0; i--) {
            buffer[i - 1] = _HEX[value & 0xf];
            value >>= 4;
        }
        return string(buffer);
    }

    bytes16 private constant _HEX = "0123456789abcdef";
}