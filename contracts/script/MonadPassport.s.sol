// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {IdentityRegistry} from "../src/IdentityRegistry.sol";
import {BlockIDShareToken} from "../src/BlockIDShareToken.sol";
import {DemoAUD} from "../src/DemoAUD.sol";
import {UpdateAnchor} from "../src/UpdateAnchor.sol";
import {BatchDividend} from "../src/BatchDividend.sol";

/// @notice TESTNET demo on Monad (chain id 10143) — Monad Metropolis 2026, Track 4. Run by scripts/monad-demo.sh.
///           1) deploy(): share register (IdentityRegistry + BlockIDShareToken), UpdateAnchor, BatchDividend, mAUD;
///              KYC + issue shares to N sample holder wallets; the issuer service records the AI-drafted update
///           -- director wallet (a different, human-held key) approves the update: cast send approve(0) --
///           2) pay(): one transaction pays a pro-rata mAUD dividend to every holder
///         DEMO ONLY: the deployer plays issuer Safe, KYC agent and recorder (production: Safe multisig).
///         Holder wallets are generated sample addresses (no keys); this is sample data, not customers.
contract MonadPassport is Script {
    /// Output path (relative to contracts/). scripts/monad-demo.sh points a deploy at a .pending file and only moves it
    /// into place after the broadcast succeeds, and keeps local dry runs in a separate file.
    function _out() internal view returns (string memory) {
        return vm.envOr("PASSPORT_OUT", string("./deployments/out/monad-passport.json"));
    }
    bytes32 constant COMPANY = keccak256("DEM");

    struct Deployed {
        IdentityRegistry reg;
        BlockIDShareToken token;
        UpdateAnchor ua;
        BatchDividend bd;
        DemoAUD aud;
        uint256 updateId;
    }

    function deploy() external {
        address director = vm.envAddress("DIRECTOR");
        bytes32 updateHash = vm.envBytes32("UPDATE_HASH");
        uint16 confidence = uint16(vm.envOr("UPDATE_CONFIDENCE_BPS", uint256(8200)));
        address[] memory holders = _holders(vm.envOr("HOLDERS", uint256(20)));

        vm.startBroadcast();
        Deployed memory d = _deployContracts(msg.sender, director);
        for (uint256 i; i < holders.length; ++i) {
            d.reg.registerInvestor(holders[i], 36, uint64(block.timestamp + 365 days), keccak256(abi.encode("kyc", i)));
            d.token.issue(holders[i], (i + 1) * 1000, keccak256("board-resolution-2026-10-issue"));
        }
        d.updateId = d.ua.propose(COMPANY, updateHash, confidence, 5, 1, "https://monad.blockid.au/#update");
        uint256 gasTopUp = vm.envOr("GAS_TOPUP_WEI", uint256(0.05 ether));
        if (director.balance < gasTopUp) payable(director).transfer(gasTopUp);
        vm.stopBroadcast();

        _write(d, msg.sender, director, updateHash, confidence, holders);
        console2.log("UpdateAnchor ", address(d.ua));
        console2.log("BatchDividend", address(d.bd));
    }

    function _deployContracts(address op, address director) internal returns (Deployed memory d) {
        d.reg = new IdentityRegistry(op);
        d.reg.grantRole(d.reg.KYC_AGENT_ROLE(), op);
        d.token = new BlockIDShareToken(
            BlockIDShareToken.InitParams({
                name: "Demo Startup Pty Ltd ORD",
                symbol: "DEM-ORD",
                companyName: "Demo Startup Pty Ltd",
                companyNumber: "ACN 000 000 000",
                shareClass: "ORD",
                identityRegistry: address(d.reg),
                issuerSafe: op,
                transferAgent: op,
                lockupUntil: 0,
                maxShareholders: 500,
                legalDocHash: keccak256("demo-constitution-v1")
            })
        );
        d.ua = new UpdateAnchor(op);
        d.ua.grantRole(d.ua.RECORDER_ROLE(), op); // issuer service records; only the director can approve
        d.ua.setDirector(COMPANY, director, true);
        d.bd = new BatchDividend(op);
        d.aud = new DemoAUD(op);
    }

    function _write(
        Deployed memory d,
        address op,
        address director,
        bytes32 updateHash,
        uint16 confidence,
        address[] memory holders
    ) internal {
        string memory o = "out";
        vm.serializeUint(o, "chainId", block.chainid);
        vm.serializeAddress(o, "operator", op);
        vm.serializeAddress(o, "director", director);
        vm.serializeAddress(o, "identityRegistry", address(d.reg));
        vm.serializeAddress(o, "shareToken", address(d.token));
        vm.serializeAddress(o, "updateAnchor", address(d.ua));
        vm.serializeAddress(o, "batchDividend", address(d.bd));
        vm.serializeAddress(o, "payToken", address(d.aud));
        vm.serializeBytes32(o, "updateHash", updateHash);
        vm.serializeUint(o, "updateConfidenceBps", confidence);
        vm.serializeAddress(o, "holders", holders);
        vm.writeJson(vm.serializeUint(o, "updateId", d.updateId), _out());
    }

    function pay() external {
        string memory d = vm.readFile(_out());
        UpdateAnchor ua = UpdateAnchor(vm.parseJsonAddress(d, ".updateAnchor"));
        BatchDividend bd = BatchDividend(vm.parseJsonAddress(d, ".batchDividend"));
        DemoAUD aud = DemoAUD(vm.parseJsonAddress(d, ".payToken"));
        address token = vm.parseJsonAddress(d, ".shareToken");
        address[] memory holders = vm.parseJsonAddressArray(d, ".holders");
        uint256 amount = vm.envOr("DIVIDEND_UNITS", uint256(1000e6)); // 1,000 mAUD (6 decimals)

        // Human gate: the dividend goes out only after the director has approved the update it is declared in.
        require(
            ua.verify(vm.parseJsonUint(d, ".updateId"), vm.parseJsonBytes32(d, ".updateHash")),
            "update not approved by a director"
        );

        vm.startBroadcast();
        aud.mint(msg.sender, amount);
        aud.approve(address(bd), amount);
        uint256 roundId = bd.distribute(token, aud, amount, holders, keccak256("board-resolution-2026-10-dividend"));
        vm.stopBroadcast();

        console2.log("paid round", roundId, "holders", holders.length);
    }

    /// @dev Sample holder wallets, strictly ascending as BatchDividend requires.
    function _holders(uint256 n) internal pure returns (address[] memory hs) {
        hs = new address[](n);
        for (uint256 i; i < n; ++i) {
            address a = address(uint160(uint256(keccak256(abi.encode("blockid.monad.sample-holder", i)))));
            uint256 j = i;
            while (j > 0 && hs[j - 1] > a) {
                hs[j] = hs[j - 1];
                --j;
            }
            hs[j] = a;
        }
    }
}
