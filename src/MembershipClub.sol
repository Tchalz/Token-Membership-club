// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/// @title Token-Gated Membership Club
/// @notice Mint a membership NFT to join. Frontend checks isMember() to gate content.
contract MembershipClub is ERC721URIStorage, Ownable, Pausable {
    uint256 public nextTokenId;
    uint256 public mintPrice = 0.01 ether;
    uint256 public maxSupply = 500;

    /// @dev Tracks whether an address has ever minted, so membership can't be
    /// re-acquired by transferring the NFT away and minting again.
    mapping(address => bool) public hasMinted;

    string public baseTokenURI;

    event Joined(address indexed member, uint256 tokenId);

    constructor(string memory _baseTokenURI) ERC721("Membership Club", "MEMBER") Ownable(msg.sender) {
        baseTokenURI = _baseTokenURI;
    }

    /// @notice Join the club by minting a membership NFT
    function join() external payable whenNotPaused {
        require(msg.value >= mintPrice, "Not enough ETH sent");
        require(nextTokenId < maxSupply, "Sold out");
        require(!hasMinted[msg.sender], "Already a member");

        uint256 tokenId = nextTokenId;
        nextTokenId++;
        hasMinted[msg.sender] = true;

        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, string(abi.encodePacked(baseTokenURI, _toString(tokenId))));

        emit Joined(msg.sender, tokenId);

        // Refund any overpayment
        if (msg.value > mintPrice) {
            (bool refunded,) = payable(msg.sender).call{value: msg.value - mintPrice}("");
            require(refunded, "Refund failed");
        }
    }

    /// @notice Frontend calls this to check gate access
    function isMember(address user) external view returns (bool) {
        return balanceOf(user) > 0;
    }

    /// @notice Owner can withdraw collected mint fees
    function withdraw() external onlyOwner {
        (bool ok,) = payable(owner()).call{value: address(this).balance}("");
        require(ok, "Withdraw failed");
    }

    /// @notice Owner can adjust price if needed
    function setMintPrice(uint256 newPrice) external onlyOwner {
        mintPrice = newPrice;
    }

    /// @notice Owner can raise supply cap, never below tokens already minted
    function setMaxSupply(uint256 newMaxSupply) external onlyOwner {
        require(newMaxSupply >= nextTokenId, "Below current supply");
        maxSupply = newMaxSupply;
    }

    /// @notice Owner can update the base metadata URI
    function setBaseTokenURI(string calldata newBaseURI) external onlyOwner {
        baseTokenURI = newBaseURI;
    }

    /// @notice Emergency stop for minting
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /// @dev Minimal uint-to-string helper (avoids pulling in a full Strings lib dependency conflict)
    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + (value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
