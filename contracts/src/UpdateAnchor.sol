// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

/// @title UpdateAnchor
/// @notice Shareholder updates drafted by the AI pipeline, anchored only after a company director approves them.
///         1) the recorder (BlockID issuer service, never an AI agent) records the draft: content hash, evidence
///            confidence and how many claims are evidenced / missing → status Proposed
///         2) a director of that company approves, directly or with an EIP-712 signature relayed by anyone.
///            Signatures go through SignatureChecker, so ERC-1271 smart accounts (passkey / P256 wallets) work too.
///         3) on approval the update is final and `UpdateAnchored` is the shareholder-facing record.
///         Four-eyes: the recorder can never approve its own draft.
contract UpdateAnchor is AccessControl, EIP712 {
    bytes32 public constant RECORDER_ROLE = keccak256("RECORDER_ROLE");
    bytes32 public constant APPROVE_TYPEHASH =
        keccak256("ApproveUpdate(uint256 updateId,bytes32 contentHash,uint256 nonce,uint256 deadline)");

    enum Status {
        None,
        Proposed,
        Anchored,
        Rejected
    }

    struct Update {
        bytes32 companyId; // keccak256(ticker), e.g. keccak256("EBA")
        bytes32 contentHash; // keccak256 of the canonical update JSON
        uint16 confidenceBps; // evidence confidence, 0–10000 (8200 = 82 %)
        uint16 evidenced; // claims backed by connected data (Stripe, Xero, GA4, GitHub)
        uint16 missing; // claims with no evidence (shown as "missing" to shareholders)
        address recorder;
        address approver;
        uint64 proposedAt;
        uint64 anchoredAt;
        Status status;
        string uri; // where shareholders read the full update
    }

    Update[] private _updates;
    mapping(bytes32 companyId => mapping(address => bool)) public isDirector;
    mapping(bytes32 companyId => uint256[]) private _byCompany;
    mapping(address => uint256) public nonces;

    event DirectorSet(bytes32 indexed companyId, address indexed director, bool enabled);
    event UpdateProposed(
        uint256 indexed updateId, bytes32 indexed companyId, bytes32 contentHash, uint16 confidenceBps, string uri
    );
    event UpdateAnchored(
        bytes32 indexed companyId,
        uint256 indexed updateId,
        bytes32 contentHash,
        uint16 confidenceBps,
        uint16 evidenced,
        uint16 missing,
        address indexed approver
    );
    event UpdateRejected(bytes32 indexed companyId, uint256 indexed updateId, address indexed director);

    error ZeroAddress();
    error BadParams();
    error NotProposed(uint256 updateId);
    error NotDirector(address who);
    error SelfApproval();
    error BadSignature();
    error Expired();

    constructor(address admin) EIP712("BlockID UpdateAnchor", "1") {
        if (admin == address(0)) revert ZeroAddress();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    // ---------------------------------------------------------------- admin

    function setDirector(bytes32 companyId, address director, bool enabled) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (director == address(0)) revert ZeroAddress();
        isDirector[companyId][director] = enabled;
        emit DirectorSet(companyId, director, enabled);
    }

    // ---------------------------------------------------------------- recorder (issuer service)

    function propose(
        bytes32 companyId,
        bytes32 contentHash,
        uint16 confidenceBps,
        uint16 evidenced,
        uint16 missing,
        string calldata uri
    ) external onlyRole(RECORDER_ROLE) returns (uint256 id) {
        if (companyId == bytes32(0) || contentHash == bytes32(0) || confidenceBps > 10_000) {
            revert BadParams();
        }
        id = _updates.length;
        _updates.push(
            Update({
                companyId: companyId,
                contentHash: contentHash,
                confidenceBps: confidenceBps,
                evidenced: evidenced,
                missing: missing,
                recorder: msg.sender,
                approver: address(0),
                proposedAt: uint64(block.timestamp),
                anchoredAt: 0,
                status: Status.Proposed,
                uri: uri
            })
        );
        _byCompany[companyId].push(id);
        emit UpdateProposed(id, companyId, contentHash, confidenceBps, uri);
    }

    // ---------------------------------------------------------------- director

    function approve(uint256 updateId) external {
        _approve(updateId, msg.sender);
    }

    /// @notice Anchor with a director's EIP-712 signature (EOA, or ERC-1271 smart account such as a passkey wallet).
    function approveWithSig(uint256 updateId, address director, uint256 deadline, bytes calldata signature) external {
        if (block.timestamp > deadline) revert Expired();
        if (updateId >= _updates.length) revert NotProposed(updateId);
        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(APPROVE_TYPEHASH, updateId, _updates[updateId].contentHash, nonces[director]++, deadline)
            )
        );
        if (!SignatureChecker.isValidSignatureNow(director, digest, signature)) revert BadSignature();
        _approve(updateId, director);
    }

    function reject(uint256 updateId) external {
        Update storage u = _proposed(updateId);
        if (!isDirector[u.companyId][msg.sender]) revert NotDirector(msg.sender);
        u.status = Status.Rejected;
        emit UpdateRejected(u.companyId, updateId, msg.sender);
    }

    function _approve(uint256 updateId, address director) internal {
        Update storage u = _proposed(updateId);
        if (!isDirector[u.companyId][director]) revert NotDirector(director);
        if (director == u.recorder) revert SelfApproval();
        u.status = Status.Anchored;
        u.approver = director;
        u.anchoredAt = uint64(block.timestamp);
        emit UpdateAnchored(u.companyId, updateId, u.contentHash, u.confidenceBps, u.evidenced, u.missing, director);
    }

    function _proposed(uint256 updateId) internal view returns (Update storage u) {
        if (updateId >= _updates.length) revert NotProposed(updateId);
        u = _updates[updateId];
        if (u.status != Status.Proposed) revert NotProposed(updateId);
    }

    // ---------------------------------------------------------------- views

    /// @notice True only if the update is director-approved and its content still hashes to `contentHash`.
    function verify(uint256 updateId, bytes32 contentHash) external view returns (bool) {
        if (updateId >= _updates.length) return false;
        Update storage u = _updates[updateId];
        return u.status == Status.Anchored && u.contentHash == contentHash;
    }

    function getUpdate(uint256 updateId) external view returns (Update memory) {
        return _updates[updateId];
    }

    function updateCount() external view returns (uint256) {
        return _updates.length;
    }

    function updatesOf(bytes32 companyId) external view returns (uint256[] memory) {
        return _byCompany[companyId];
    }

    function domainSeparator() external view returns (bytes32) {
        return _domainSeparatorV4();
    }
}
