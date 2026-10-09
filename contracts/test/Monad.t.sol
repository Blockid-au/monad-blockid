// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {UpdateAnchor} from "../src/UpdateAnchor.sol";
import {BatchDividend} from "../src/BatchDividend.sol";

contract Stable is ERC20 {
    constructor() ERC20("Mock AUD Stable", "mAUD") {}

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amt) external {
        _mint(to, amt);
    }
}

/// @dev Plain ERC-20 share stand-in: BatchDividend only reads balanceOf / totalSupply.
contract Shares is ERC20 {
    constructor() ERC20("Demo ORD", "DEM-ORD") {}

    function mint(address to, uint256 amt) external {
        _mint(to, amt);
    }
}

/// @dev Minimal ERC-1271 smart account (stands in for a passkey / P256 wallet): valid if its owner key signed.
contract SmartAccount is IERC1271 {
    address public immutable owner;

    constructor(address o) {
        owner = o;
    }

    function isValidSignature(bytes32 hash, bytes calldata sig) external view returns (bytes4) {
        (address rec,,) = ECDSA.tryRecover(hash, sig);
        return rec == owner ? IERC1271.isValidSignature.selector : bytes4(0xffffffff);
    }
}

contract UpdateAnchorTest is Test {
    UpdateAnchor ua;
    address admin = makeAddr("admin");
    address recorder = makeAddr("recorder");
    address director;
    uint256 directorKey;
    bytes32 constant EBA = keccak256("EBA");
    bytes32 constant H = keccak256("update-2026-10");

    function setUp() public {
        (director, directorKey) = makeAddrAndKey("director");
        ua = new UpdateAnchor(admin);
        bytes32 role = ua.RECORDER_ROLE();
        vm.startPrank(admin);
        ua.grantRole(role, recorder);
        ua.setDirector(EBA, director, true);
        vm.stopPrank();
    }

    function _propose() internal returns (uint256) {
        vm.prank(recorder);
        return ua.propose(EBA, H, 8200, 5, 1, "https://monad.blockid.au/u/0");
    }

    function _sig(uint256 key, address who, uint256 id, uint256 nonce, uint256 deadline)
        internal
        view
        returns (bytes memory)
    {
        bytes32 sh = keccak256(abi.encode(ua.APPROVE_TYPEHASH(), id, H, who, nonce, deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", ua.domainSeparator(), sh));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }

    function test_proposeThenDirectorApproves() public {
        uint256 id = _propose();
        assertFalse(ua.verify(id, H));
        vm.expectEmit(true, true, true, true);
        emit UpdateAnchor.UpdateAnchored(EBA, id, H, 8200, 5, 1, director);
        vm.prank(director);
        ua.approve(id);
        assertTrue(ua.verify(id, H));
        assertFalse(ua.verify(id, keccak256("tampered")));
        assertEq(ua.getUpdate(id).approver, director);
        assertEq(ua.updatesOf(EBA).length, 1);
    }

    function test_onlyRecorderProposes() public {
        vm.expectRevert();
        vm.prank(director);
        ua.propose(EBA, H, 8200, 5, 1, "");
    }

    function test_rejectsBadConfidence() public {
        vm.prank(recorder);
        vm.expectRevert(UpdateAnchor.BadParams.selector);
        ua.propose(EBA, H, 10_001, 0, 0, "");
    }

    function test_nonDirectorCannotApprove() public {
        uint256 id = _propose();
        vm.prank(makeAddr("stranger"));
        vm.expectRevert(abi.encodeWithSelector(UpdateAnchor.NotDirector.selector, makeAddr("stranger")));
        ua.approve(id);
    }

    function test_recorderCannotBeDirector() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(UpdateAnchor.RecorderCannotBeDirector.selector, recorder));
        ua.setDirector(EBA, recorder, true);
    }

    function test_directorLaterMadeRecorderCannotApprove() public {
        uint256 id = _propose();
        bytes32 role = ua.RECORDER_ROLE();
        vm.prank(admin);
        ua.grantRole(role, director);
        vm.prank(director);
        vm.expectRevert(UpdateAnchor.SelfApproval.selector);
        ua.approve(id);
    }

    function test_signatureBoundToDirector() public {
        // a second director account controlled by the same key cannot reuse the first director's signature
        (address owner, uint256 ownerKey) = makeAddrAndKey("shared-owner");
        SmartAccount a1 = new SmartAccount(owner);
        SmartAccount a2 = new SmartAccount(owner);
        vm.startPrank(admin);
        ua.setDirector(EBA, address(a1), true);
        ua.setDirector(EBA, address(a2), true);
        vm.stopPrank();
        uint256 id = _propose();
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sig(ownerKey, address(a1), id, 0, deadline);
        vm.expectRevert(UpdateAnchor.BadSignature.selector);
        ua.approveWithSig(id, address(a2), deadline, sig);
        ua.approveWithSig(id, address(a1), deadline, sig);
        assertEq(ua.getUpdate(id).approver, address(a1));
    }

    function test_cannotApproveTwiceOrAfterReject() public {
        uint256 id = _propose();
        vm.prank(director);
        ua.reject(id);
        vm.prank(director);
        vm.expectRevert(abi.encodeWithSelector(UpdateAnchor.NotProposed.selector, id));
        ua.approve(id);
    }

    function test_approveWithEoaSignature_relayedByAnyone() public {
        uint256 id = _propose();
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sig(directorKey, director, id, 0, deadline);
        vm.prank(makeAddr("relayer"));
        ua.approveWithSig(id, director, deadline, sig);
        assertTrue(ua.verify(id, H));
        assertEq(ua.nonces(director), 1);
    }

    function test_signatureReplayAndExpiry() public {
        uint256 id = _propose();
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sig(directorKey, director, id, 0, deadline);
        vm.warp(deadline + 1);
        vm.expectRevert(UpdateAnchor.Expired.selector);
        ua.approveWithSig(id, director, deadline, sig);

        vm.warp(1);
        uint256 id2 = _propose();
        ua.approveWithSig(id2, director, deadline, _sig(directorKey, director, id2, 0, deadline));
        uint256 id3 = _propose();
        // nonce 0 already used: an old signature cannot be replayed on a new update
        bytes memory stale = _sig(directorKey, director, id3, 0, deadline);
        vm.expectRevert(UpdateAnchor.BadSignature.selector);
        ua.approveWithSig(id3, director, deadline, stale);
    }

    function test_approveWithSmartAccountSignature() public {
        (address owner, uint256 ownerKey) = makeAddrAndKey("passkey-owner");
        SmartAccount acct = new SmartAccount(owner);
        vm.prank(admin);
        ua.setDirector(EBA, address(acct), true);
        uint256 id = _propose();
        uint256 deadline = block.timestamp + 1 hours;
        ua.approveWithSig(id, address(acct), deadline, _sig(ownerKey, address(acct), id, 0, deadline));
        assertEq(ua.getUpdate(id).approver, address(acct));

        uint256 id2 = _propose();
        (, uint256 otherKey) = makeAddrAndKey("someone-else");
        bytes memory forged = _sig(otherKey, address(acct), id2, 1, deadline);
        vm.expectRevert(UpdateAnchor.BadSignature.selector);
        ua.approveWithSig(id2, address(acct), deadline, forged);
    }
}

contract BatchDividendTest is Test {
    BatchDividend bd;
    UpdateAnchor ua;
    Stable aud;
    Shares sh;
    address issuer = makeAddr("issuer");
    address director = makeAddr("director");
    bytes32 constant DEM = keccak256("DEM");

    function setUp() public {
        ua = new UpdateAnchor(issuer);
        bd = new BatchDividend(issuer, ua);
        aud = new Stable();
        sh = new Shares();
        bytes32 role = ua.RECORDER_ROLE();
        vm.startPrank(issuer);
        ua.grantRole(role, issuer);
        ua.setDirector(DEM, director, true);
        bd.setCompany(address(sh), DEM);
        vm.stopPrank();
    }

    function _update(bytes32 company, bool approve_) internal returns (uint256 id) {
        bytes32 h = keccak256(abi.encode("dividend-update", ua.updateCount()));
        vm.prank(issuer);
        id = ua.propose(company, h, 8200, 5, 1, "");
        if (approve_) {
            vm.prank(director);
            ua.approve(id);
        }
    }

    function _approved() internal returns (uint256) {
        return _update(DEM, true);
    }

    /// @dev n holders at addresses 0x1000.., strictly ascending; holder i holds (i + 1) * 100 shares.
    function _register(uint256 n) internal returns (address[] memory hs) {
        hs = new address[](n);
        for (uint256 i; i < n; ++i) {
            hs[i] = address(uint160(0x1000 + i));
            sh.mint(hs[i], (i + 1) * 100);
        }
    }

    function _fund(uint256 amount) internal {
        aud.mint(issuer, amount);
        vm.prank(issuer);
        aud.approve(address(bd), amount);
    }

    function test_paysProRataInOneTransaction() public {
        address[] memory hs = _register(3); // 100 / 200 / 300 of 600
        _fund(600e6);
        uint256 upd = _approved();
        vm.prank(issuer);
        uint256 id = bd.distribute(address(sh), aud, 600e6, hs, upd);
        assertEq(aud.balanceOf(hs[0]), 100e6);
        assertEq(aud.balanceOf(hs[1]), 200e6);
        assertEq(aud.balanceOf(hs[2]), 300e6);
        assertEq(bd.getRound(id).total, 600e6);
        assertEq(bd.getRound(id).holders, 3);
        assertEq(bd.getRound(id).updateId, upd);
        assertEq(bd.getRound(id).resolutionRef, ua.getUpdate(upd).contentHash);
        assertTrue(bd.paidFor(upd));
    }

    function test_refusesWithoutDirectorApproval() public {
        address[] memory hs = _register(3);
        _fund(600e6);
        uint256 upd = _update(DEM, false);
        vm.prank(issuer);
        vm.expectRevert(abi.encodeWithSelector(BatchDividend.UpdateNotApproved.selector, upd));
        bd.distribute(address(sh), aud, 600e6, hs, upd);

        vm.prank(issuer);
        vm.expectRevert(abi.encodeWithSelector(BatchDividend.UpdateNotApproved.selector, 99));
        bd.distribute(address(sh), aud, 600e6, hs, 99);

        vm.prank(director);
        ua.reject(upd);
        vm.prank(issuer);
        vm.expectRevert(abi.encodeWithSelector(BatchDividend.UpdateNotApproved.selector, upd));
        bd.distribute(address(sh), aud, 600e6, hs, upd);
    }

    function test_refusesUpdateOfAnotherCompany() public {
        address[] memory hs = _register(3);
        _fund(600e6);
        bytes32 other = keccak256("OTH");
        vm.prank(issuer);
        ua.setDirector(other, director, true);
        uint256 upd = _update(other, true);
        vm.prank(issuer);
        vm.expectRevert(abi.encodeWithSelector(BatchDividend.WrongCompany.selector, upd));
        bd.distribute(address(sh), aud, 600e6, hs, upd);
    }

    function test_refusesUnlinkedShareToken() public {
        Shares s2 = new Shares();
        address[] memory hs = new address[](1);
        hs[0] = address(0x1000);
        s2.mint(hs[0], 1);
        _fund(1e6);
        uint256 upd = _approved();
        vm.prank(issuer);
        vm.expectRevert(abi.encodeWithSelector(BatchDividend.UnknownShareToken.selector, address(s2)));
        bd.distribute(address(s2), aud, 1e6, hs, upd);
    }

    function test_eachUpdatePaysOnce() public {
        address[] memory hs = _register(3);
        _fund(1200e6);
        uint256 upd = _approved();
        vm.prank(issuer);
        bd.distribute(address(sh), aud, 600e6, hs, upd);
        vm.prank(issuer);
        vm.expectRevert(abi.encodeWithSelector(BatchDividend.AlreadyPaid.selector, upd));
        bd.distribute(address(sh), aud, 600e6, hs, upd);
    }

    function test_refusesPayTokenEqualToShareToken() public {
        address[] memory hs = _register(1);
        uint256 upd = _approved();
        vm.prank(issuer);
        vm.expectRevert(BatchDividend.BadParams.selector);
        bd.distribute(address(sh), IERC20(address(sh)), 1, hs, upd);
    }

    function test_dustReturnedToPayer() public {
        address[] memory hs = _register(3);
        _fund(1000);
        uint256 upd = _approved();
        vm.prank(issuer);
        bd.distribute(address(sh), aud, 1000, hs, upd);
        // 166 + 333 + 500 = 999 paid, 1 unit of dust back to the issuer
        assertEq(aud.balanceOf(issuer), 1);
        assertEq(aud.balanceOf(address(bd)), 0);
    }

    function test_revertsWhenHolderLeftOut_beforeAnyTransfer() public {
        address[] memory hs = _register(3);
        address[] memory two = new address[](2);
        two[0] = hs[0];
        two[1] = hs[1];
        _fund(600e6);
        uint256 upd = _approved();
        vm.prank(issuer);
        vm.expectRevert(abi.encodeWithSelector(BatchDividend.IncompleteRegister.selector, 300, 600));
        bd.distribute(address(sh), aud, 600e6, two, upd);
        assertFalse(bd.paidFor(upd));
    }

    function test_revertsOnDuplicateOrUnsorted() public {
        address[] memory hs = _register(3);
        hs[2] = hs[1];
        _fund(600e6);
        uint256 upd = _approved();
        vm.prank(issuer);
        vm.expectRevert(abi.encodeWithSelector(BatchDividend.NotSorted.selector, 2));
        bd.distribute(address(sh), aud, 600e6, hs, upd);
    }

    function test_onlyIssuer() public {
        address[] memory hs = _register(1);
        uint256 upd = _approved();
        vm.expectRevert();
        bd.distribute(address(sh), aud, 1, hs, upd);
    }

    /// @dev Gas benchmark for the README table: `forge test --match-test bench -vv`.
    function test_bench_gasPerRegisterSize() public {
        uint256[3] memory sizes = [uint256(10), 50, 200];
        for (uint256 k; k < 3; ++k) {
            BatchDividend b = new BatchDividend(issuer, ua);
            Shares s = new Shares();
            vm.prank(issuer);
            b.setCompany(address(s), DEM);
            uint256 n = sizes[k];
            address[] memory hs = new address[](n);
            for (uint256 i; i < n; ++i) {
                hs[i] = address(uint160(0x100000 * (k + 1) + i));
                s.mint(hs[i], 1000);
            }
            uint256 upd = _approved();
            aud.mint(issuer, 1000e6);
            vm.startPrank(issuer);
            aud.approve(address(b), 1000e6);
            uint256 g = gasleft();
            b.distribute(address(s), aud, 1000e6, hs, upd);
            g -= gasleft();
            vm.stopPrank();
            console2.log("holders", n, "gas", g);
            console2.log("  gas per holder", g / n);
        }
    }
}
