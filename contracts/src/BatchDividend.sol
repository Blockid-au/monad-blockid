// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {UpdateAnchor} from "./UpdateAnchor.sol";

/// @title BatchDividend
/// @notice Push-style dividend: one transaction pays every shareholder pro-rata, straight to the wallet. The
///         per-holder `DividendPaid` events double as the shareholder's payment record.
///         Complements DividendDistributor (Merkle claim, best for very large registers): on Monad a register of a
///         few hundred holders fits in one transaction at low cost, so holders never need to claim.
/// @dev    Enforced on-chain:
///         - the dividend is declared in a shareholder update that a director approved in UpdateAnchor, for the same
///           company as the share token, and each approved update pays at most once;
///         - `holders` are strictly ascending (no duplicates) and their balances add up to the share token's total
///           supply (nobody left out). This is checked before any transfer.
///         Rounding dust (< 1 unit per holder) is returned to the payer.
contract BatchDividend is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");

    UpdateAnchor public immutable anchor;

    struct Round {
        address shareToken;
        IERC20 payToken;
        uint256 total; // amount actually paid out (declared minus dust)
        uint256 supply; // share supply at payment
        uint32 holders;
        uint64 paidAt;
        uint256 updateId; // the director-approved update declaring this dividend
        bytes32 resolutionRef; // that update's content hash
    }

    Round[] private _rounds;
    mapping(address shareToken => bytes32 companyId) public companyOf;
    mapping(uint256 updateId => bool) public paidFor;

    event CompanySet(address indexed shareToken, bytes32 indexed companyId);
    event DividendPaid(uint256 indexed roundId, address indexed holder, uint256 shares, uint256 amount);
    event RoundPaid(
        uint256 indexed roundId,
        address indexed shareToken,
        address payToken,
        uint256 total,
        uint32 holders,
        uint256 indexed updateId,
        bytes32 resolutionRef
    );

    error BadParams();
    error NotSorted(uint256 index);
    error IncompleteRegister(uint256 listed, uint256 supply);
    error UnknownShareToken(address shareToken);
    error UpdateNotApproved(uint256 updateId);
    error WrongCompany(uint256 updateId);
    error AlreadyPaid(uint256 updateId);

    constructor(address admin, UpdateAnchor anchor_) {
        if (admin == address(0) || address(anchor_) == address(0)) revert BadParams();
        anchor = anchor_;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ISSUER_ROLE, admin);
    }

    /// @notice Link a share token to its company id in UpdateAnchor (keccak256 of the ticker).
    function setCompany(address shareToken, bytes32 companyId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (shareToken == address(0) || companyId == bytes32(0)) revert BadParams();
        companyOf[shareToken] = companyId;
        emit CompanySet(shareToken, companyId);
    }

    /// @notice Pay `amount` of `payToken` pro-rata to `holders` of `shareToken`, in one transaction, against the
    ///         director-approved update `updateId`. The caller must have approved this contract for `amount`.
    function distribute(
        address shareToken,
        IERC20 payToken,
        uint256 amount,
        address[] calldata holders,
        uint256 updateId
    ) external onlyRole(ISSUER_ROLE) nonReentrant returns (uint256 roundId) {
        uint256 n = holders.length;
        if (shareToken == address(0) || address(payToken) == address(0) || shareToken == address(payToken)) {
            revert BadParams();
        }
        if (amount == 0 || n == 0) revert BadParams();
        bytes32 resolutionRef = _checkUpdate(shareToken, updateId);
        paidFor[updateId] = true;

        IERC20 shares = IERC20(shareToken);
        uint256 supply = shares.totalSupply();
        if (supply == 0) revert BadParams();
        _checkRegister(shares, supply, holders);

        payToken.safeTransferFrom(msg.sender, address(this), amount);
        roundId = _rounds.length;
        uint256 paid = _pay(shares, payToken, amount, supply, holders, roundId);
        if (amount > paid) payToken.safeTransfer(msg.sender, amount - paid);

        _rounds.push(
            Round({
                shareToken: shareToken,
                payToken: payToken,
                total: paid,
                supply: supply,
                holders: uint32(n),
                paidAt: uint64(block.timestamp),
                updateId: updateId,
                resolutionRef: resolutionRef
            })
        );
        emit RoundPaid(roundId, shareToken, address(payToken), paid, uint32(n), updateId, resolutionRef);
    }

    function _checkUpdate(address shareToken, uint256 updateId) internal view returns (bytes32) {
        bytes32 company = companyOf[shareToken];
        if (company == bytes32(0)) revert UnknownShareToken(shareToken);
        if (updateId >= anchor.updateCount()) revert UpdateNotApproved(updateId);
        UpdateAnchor.Update memory u = anchor.getUpdate(updateId);
        if (u.status != UpdateAnchor.Status.Anchored) revert UpdateNotApproved(updateId);
        if (u.companyId != company) revert WrongCompany(updateId);
        if (paidFor[updateId]) revert AlreadyPaid(updateId);
        return u.contentHash;
    }

    /// @dev First pass, reads only: holders sorted and unique, balances add up to total supply.
    function _checkRegister(IERC20 shares, uint256 supply, address[] calldata holders) internal view {
        address prev;
        uint256 listed;
        for (uint256 i; i < holders.length; ++i) {
            address h = holders[i];
            if (h <= prev) revert NotSorted(i);
            prev = h;
            listed += shares.balanceOf(h);
        }
        if (listed != supply) revert IncompleteRegister(listed, supply);
    }

    function _pay(
        IERC20 shares,
        IERC20 payToken,
        uint256 amount,
        uint256 supply,
        address[] calldata holders,
        uint256 roundId
    ) internal returns (uint256 paid) {
        for (uint256 i; i < holders.length; ++i) {
            address h = holders[i];
            uint256 bal = shares.balanceOf(h);
            uint256 amt = amount * bal / supply;
            if (amt != 0) {
                paid += amt;
                payToken.safeTransfer(h, amt);
            }
            emit DividendPaid(roundId, h, bal, amt);
        }
    }

    function roundCount() external view returns (uint256) {
        return _rounds.length;
    }

    function getRound(uint256 roundId) external view returns (Round memory) {
        return _rounds[roundId];
    }
}
