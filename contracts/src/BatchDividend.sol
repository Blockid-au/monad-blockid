// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title BatchDividend
/// @notice Push-style dividend: one director-declared transaction pays every shareholder pro-rata, straight to the
///         wallet. The per-holder `DividendPaid` events double as the shareholder's payment record.
///         Complements DividendDistributor (Merkle claim, best for very large registers): on Monad a register of a
///         few hundred holders fits in one transaction at low cost, so holders never need to claim.
/// @dev    Completeness and uniqueness are enforced on-chain: `holders` must be strictly ascending (no duplicates)
///         and their balances must add up to the share token's total supply (nobody left out).
///         Rounding dust (< 1 unit per holder) is returned to the payer.
contract BatchDividend is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");

    struct Round {
        address shareToken;
        IERC20 payToken;
        uint256 total; // amount actually paid out (declared minus dust)
        uint256 supply; // share supply at payment
        uint32 holders;
        uint64 paidAt;
        bytes32 resolutionRef; // board resolution declaring the dividend
    }

    Round[] private _rounds;

    event DividendPaid(uint256 indexed roundId, address indexed holder, uint256 shares, uint256 amount);
    event RoundPaid(
        uint256 indexed roundId,
        address indexed shareToken,
        address payToken,
        uint256 total,
        uint32 holders,
        bytes32 resolutionRef
    );

    error BadParams();
    error NotSorted(uint256 index);
    error IncompleteRegister(uint256 listed, uint256 supply);

    constructor(address admin) {
        if (admin == address(0)) revert BadParams();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ISSUER_ROLE, admin);
    }

    /// @notice Pay `amount` of `payToken` pro-rata to `holders` of `shareToken`, in one transaction.
    ///         The caller must have approved this contract for `amount`.
    function distribute(
        address shareToken,
        IERC20 payToken,
        uint256 amount,
        address[] calldata holders,
        bytes32 resolutionRef
    ) external onlyRole(ISSUER_ROLE) nonReentrant returns (uint256 roundId) {
        uint256 n = holders.length;
        if (shareToken == address(0) || address(payToken) == address(0) || amount == 0 || n == 0) revert BadParams();
        IERC20 shares = IERC20(shareToken);
        uint256 supply = shares.totalSupply();
        if (supply == 0) revert BadParams();

        payToken.safeTransferFrom(msg.sender, address(this), amount);
        roundId = _rounds.length;

        (uint256 listed, uint256 paid) = _pay(shares, payToken, amount, supply, holders, roundId);
        if (listed != supply) revert IncompleteRegister(listed, supply);
        if (amount > paid) payToken.safeTransfer(msg.sender, amount - paid);

        _rounds.push(
            Round({
                shareToken: shareToken,
                payToken: payToken,
                total: paid,
                supply: supply,
                holders: uint32(n),
                paidAt: uint64(block.timestamp),
                resolutionRef: resolutionRef
            })
        );
        emit RoundPaid(roundId, shareToken, address(payToken), paid, uint32(n), resolutionRef);
    }

    function _pay(
        IERC20 shares,
        IERC20 payToken,
        uint256 amount,
        uint256 supply,
        address[] calldata holders,
        uint256 roundId
    ) internal returns (uint256 listed, uint256 paid) {
        address prev;
        for (uint256 i; i < holders.length; ++i) {
            address h = holders[i];
            if (h <= prev) revert NotSorted(i);
            prev = h;
            uint256 bal = shares.balanceOf(h);
            listed += bal;
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
